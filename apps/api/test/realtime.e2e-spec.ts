import { randomUUID } from 'node:crypto';
import type { Server } from 'node:http';
import type { AddressInfo } from 'node:net';
import { JwtService } from '@nestjs/jwt';
import { io, type Socket } from 'socket.io-client';
import request from 'supertest';
import {
  bearer,
  createTeam,
  createTestApp,
  pushOps,
  registerUser,
  resetState,
  syncOp,
  type TestApp,
  type TestUser,
} from './utils.js';

interface JoinAck {
  ok: boolean;
  code?: string;
}

const now = () => new Date().toISOString();

describe('Realtime (e2e)', () => {
  let app: TestApp;
  let url: string;
  let alice: TestUser;
  let bob: TestUser;
  let workspaceId: string;
  let boardId: string;
  let cardId: string;
  const sockets: Socket[] = [];

  function connect(token?: string): Promise<Socket> {
    const socket = io(url, {
      auth: token === undefined ? {} : { token },
      transports: ['websocket'],
      reconnection: false,
      forceNew: true,
    });
    sockets.push(socket);
    return new Promise((resolve, reject) => {
      socket.once('connect', () => {
        resolve(socket);
      });
      socket.once('connect_error', reject);
    });
  }

  const join = (socket: Socket, id: string): Promise<JoinAck> =>
    socket.emitWithAck('board:join', { boardId: id }) as Promise<JoinAck>;

  /** Resolves with the next [event] payload, or fails after [ms]. */
  function next(socket: Socket, event: string, ms = 1000): Promise<unknown> {
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        reject(new Error(`No "${event}" within ${String(ms)} ms`));
      }, ms);
      socket.once(event, (payload: unknown) => {
        clearTimeout(timer);
        resolve(payload);
      });
    });
  }

  function record(socket: Socket, event: string): unknown[] {
    const received: unknown[] = [];
    socket.on(event, (payload: unknown) => received.push(payload));
    return received;
  }

  const settle = () => new Promise((resolve) => setTimeout(resolve, 300));

  const renameCard = (user: TestUser, title: string) =>
    pushOps(app, user, [syncOp('card', 'update', cardId, { title })]);

  beforeAll(async () => {
    app = await createTestApp();
    const { port } = (
      app.getHttpServer() as unknown as Server
    ).address() as AddressInfo;
    url = `http://127.0.0.1:${String(port)}`;
  });

  beforeEach(async () => {
    await resetState(app);
    ({ alice, bob, workspaceId } = await createTeam(app));
    boardId = randomUUID();
    const columnId = randomUUID();
    cardId = randomUUID();
    const results = await pushOps(app, alice, [
      syncOp('board', 'create', boardId, {
        workspaceId,
        title: 'B',
        createdAt: now(),
      }),
      syncOp('column', 'create', columnId, {
        boardId,
        title: 'To do',
        position: 'a0',
        createdAt: now(),
      }),
      syncOp('card', 'create', cardId, {
        boardId,
        columnId,
        title: 'Card',
        position: 'a0',
        createdAt: now(),
      }),
    ]);
    expect(results.every((r) => r.status === 'applied')).toBe(true);
  });

  afterEach(() => {
    for (const socket of sockets.splice(0)) socket.disconnect();
  });

  afterAll(async () => {
    await app.close();
  });

  it('rejects handshakes without a valid access token', async () => {
    await expect(connect()).rejects.toThrow('UNAUTHORIZED');
    await expect(connect('not-a-jwt')).rejects.toThrow('UNAUTHORIZED');
    const forged = new JwtService({ secret: 'x'.repeat(32) }).sign({
      sub: bob.id,
      email: bob.email,
    });
    await expect(connect(forged)).rejects.toThrow('UNAUTHORIZED');
  });

  it('tells members in the board room that the board changed', async () => {
    const bobSocket = await connect(bob.accessToken);
    expect(await join(bobSocket, boardId)).toEqual({ ok: true });
    // Alice's second device is connected but has not opened the board.
    const idle = record(await connect(alice.accessToken), 'board:changed');

    const event = next(bobSocket, 'board:changed');
    const started = Date.now();
    await renameCard(alice, 'Moved');
    expect(await event).toEqual({ boardId });
    expect(Date.now() - started).toBeLessThan(1000);

    await settle();
    expect(idle).toEqual([]);
  });

  it('keeps outsiders out of board rooms', async () => {
    const eve = await registerUser(app, 'Eve');
    const eveSocket = await connect(eve.accessToken);
    const received = record(eveSocket, 'board:changed');

    expect(await join(eveSocket, boardId)).toEqual({
      ok: false,
      code: 'NOT_FOUND',
    });
    expect(await join(eveSocket, randomUUID())).toEqual({
      ok: false,
      code: 'NOT_FOUND',
    });
    expect(
      await eveSocket.emitWithAck('board:join', { boardId: 'nope' }),
    ).toEqual({ ok: false, code: 'INVALID' });

    await renameCard(alice, 'Secret');
    await settle();
    expect(received).toEqual([]);
  });

  it('stops events after leaving a room', async () => {
    const bobSocket = await connect(bob.accessToken);
    const received = record(bobSocket, 'board:changed');
    await join(bobSocket, boardId);
    expect(await bobSocket.emitWithAck('board:leave', { boardId })).toEqual({
      ok: true,
    });

    await renameCard(alice, 'Quiet');
    await settle();
    expect(received).toEqual([]);
  });

  it('removes a former member from board rooms', async () => {
    const bobSocket = await connect(bob.accessToken);
    await join(bobSocket, boardId);
    const changes = record(bobSocket, 'board:changed');

    const removed = next(bobSocket, 'workspace:removed');
    await request(app.getHttpServer())
      .delete(`/workspaces/${workspaceId}/members/${bob.id}`)
      .set(...bearer(alice))
      .expect(204);
    expect(await removed).toEqual({ workspaceId });

    await renameCard(alice, 'After Bob');
    await settle();
    expect(changes).toEqual([]);
    expect(await join(bobSocket, boardId)).toEqual({
      ok: false,
      code: 'NOT_FOUND',
    });
  });

  it('disconnects a socket when its access token expires', async () => {
    const shortLived = app
      .get(JwtService)
      .sign({ sub: bob.id, email: bob.email }, { expiresIn: 1 });
    const socket = await connect(shortLived);
    expect(await next(socket, 'disconnect', 3000)).toBe('io server disconnect');
  });
});
