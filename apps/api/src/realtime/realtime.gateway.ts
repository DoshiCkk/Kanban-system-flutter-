import { Logger, OnModuleDestroy } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  OnGatewayInit,
  SubscribeMessage,
  WebSocketGateway,
} from '@nestjs/websockets';
import { isUUID } from 'class-validator';
import type { Subscription } from 'rxjs';
import type { DefaultEventsMap, Server, Socket } from 'socket.io';
import type { JwtPayload } from '../auth/auth-user.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { SyncService } from '../sync/sync.service.js';
import {
  type MembershipRevoked,
  WorkspacesService,
} from '../workspaces/workspaces.service.js';

/** Server → client events (docs/realtime.md). */
export const RealtimeEvent = {
  /** `{ boardId }`: the board changed on the server; pull it. */
  BoardChanged: 'board:changed',
  /** `{ workspaceId }`: the user lost access; pull to clean up. */
  WorkspaceRemoved: 'workspace:removed',
} as const;

export type JoinAck =
  | { ok: true }
  | { ok: false; code: 'INVALID' | 'NOT_FOUND' | 'TOO_MANY_ROOMS' };

interface SocketData {
  userId: string;
  /** Access token expiry, ms since epoch. */
  expiresAt: number;
}

type ClientSocket = Socket<
  DefaultEventsMap,
  DefaultEventsMap,
  DefaultEventsMap,
  SocketData
>;
type IoServer = Server<
  DefaultEventsMap,
  DefaultEventsMap,
  DefaultEventsMap,
  SocketData
>;

/** Board rooms per socket, besides its own id room and the user room. */
const MAX_BOARD_ROOMS = 50;
/** setTimeout overflows above 2^31 - 1 ms. */
const MAX_TIMER_MS = 2 ** 31 - 1;

export const boardRoom = (boardId: string): string => `board:${boardId}`;
export const userRoom = (userId: string): string => `user:${userId}`;

const boardIdOf = (body: unknown): string | null => {
  if (typeof body !== 'object' || body === null) return null;
  const { boardId } = body as { boardId?: unknown };
  return typeof boardId === 'string' && isUUID(boardId) ? boardId : null;
};

const unauthorized = (): Error =>
  Object.assign(new Error('UNAUTHORIZED'), { data: { code: 'UNAUTHORIZED' } });

/**
 * Live updates (docs/realtime.md). The client authenticates in the
 * handshake with its access token, joins `board:<id>` rooms of the boards on
 * screen and pulls when told a board changed. Events carry ids only: data
 * always travels through `/sync/pull`, which enforces membership.
 */
@WebSocketGateway()
export class RealtimeGateway
  implements
    OnGatewayInit<IoServer>,
    OnGatewayConnection<ClientSocket>,
    OnGatewayDisconnect<ClientSocket>,
    OnModuleDestroy
{
  private readonly logger = new Logger(RealtimeGateway.name);
  private readonly subscriptions: Subscription[] = [];
  /** Disconnects each socket when its access token expires. */
  private readonly expiryTimers = new Map<string, NodeJS.Timeout>();
  private server!: IoServer;

  constructor(
    private readonly jwt: JwtService,
    private readonly prisma: PrismaService,
    private readonly sync: SyncService,
    private readonly workspaces: WorkspacesService,
  ) {}

  afterInit(server: IoServer): void {
    this.server = server;
    server.use((socket, next) => {
      this.authenticate(socket).then(
        () => {
          next();
        },
        () => {
          next(unauthorized());
        },
      );
    });
    this.subscriptions.push(
      this.sync.boardsChanged.subscribe(({ boardIds }) => {
        for (const boardId of boardIds) {
          server
            .to(boardRoom(boardId))
            .emit(RealtimeEvent.BoardChanged, { boardId });
        }
      }),
      this.workspaces.membershipRevoked.subscribe((event) => {
        this.revoke(event).catch((error: unknown) => {
          this.logger.error('Failed to revoke board rooms', error);
        });
      }),
    );
  }

  onModuleDestroy(): void {
    for (const s of this.subscriptions) s.unsubscribe();
    for (const timer of this.expiryTimers.values()) clearTimeout(timer);
    this.expiryTimers.clear();
  }

  private async authenticate(socket: ClientSocket): Promise<void> {
    const { token } = socket.handshake.auth as { token?: unknown };
    if (typeof token !== 'string') throw unauthorized();
    const payload = await this.jwt.verifyAsync<JwtPayload & { exp: number }>(
      token,
    );
    socket.data.userId = payload.sub;
    socket.data.expiresAt = payload.exp * 1000;
  }

  async handleConnection(socket: ClientSocket): Promise<void> {
    const delay = Math.min(socket.data.expiresAt - Date.now(), MAX_TIMER_MS);
    // A server-side disconnect makes the client reconnect with a fresh token.
    this.expiryTimers.set(
      socket.id,
      setTimeout(() => socket.disconnect(true), Math.max(delay, 0)),
    );
    await socket.join(userRoom(socket.data.userId));
  }

  handleDisconnect(socket: ClientSocket): void {
    clearTimeout(this.expiryTimers.get(socket.id));
    this.expiryTimers.delete(socket.id);
  }

  @SubscribeMessage('board:join')
  async join(
    @ConnectedSocket() socket: ClientSocket,
    @MessageBody() body: unknown,
  ): Promise<JoinAck> {
    const boardId = boardIdOf(body);
    if (!boardId) return { ok: false, code: 'INVALID' };
    // Rooms always include the socket's own id and its user room.
    if (socket.rooms.size >= MAX_BOARD_ROOMS + 2) {
      return { ok: false, code: 'TOO_MANY_ROOMS' };
    }
    const board = await this.prisma.board.findFirst({
      where: {
        id: boardId,
        deletedAt: null,
        workspace: {
          deletedAt: null,
          memberships: { some: { userId: socket.data.userId } },
        },
      },
      select: { id: true },
    });
    // Same answer for "missing" and "not yours", as in REST.
    if (!board) return { ok: false, code: 'NOT_FOUND' };
    await socket.join(boardRoom(boardId));
    return { ok: true };
  }

  @SubscribeMessage('board:leave')
  async leave(
    @ConnectedSocket() socket: ClientSocket,
    @MessageBody() body: unknown,
  ): Promise<JoinAck> {
    const boardId = boardIdOf(body);
    if (!boardId) return { ok: false, code: 'INVALID' };
    await socket.leave(boardRoom(boardId));
    return { ok: true };
  }

  /** Removes a former member from the workspace's board rooms. */
  private async revoke({
    userId,
    workspaceId,
  }: MembershipRevoked): Promise<void> {
    const boards = await this.prisma.board.findMany({
      where: { workspaceId },
      select: { id: true },
    });
    const sockets = this.server.in(userRoom(userId));
    if (boards.length > 0)
      sockets.socketsLeave(boards.map((b) => boardRoom(b.id)));
    this.server
      .to(userRoom(userId))
      .emit(RealtimeEvent.WorkspaceRemoved, { workspaceId });
  }
}
