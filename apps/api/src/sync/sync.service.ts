import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { Subject } from 'rxjs';
import { notFound } from '../common/api-error.js';
import { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import {
  DEFAULT_PULL_LIMIT,
  type PullQueryDto,
  type PullResponseDto,
  type PushOpDto,
  type PushResultDto,
} from './sync.dto.js';
import {
  type Applied,
  HANDLERS,
  SyncRejection,
  type Tx,
} from './sync.handlers.js';
import { pick, UPDATE_KEYS } from './sync.payloads.js';

/** Emitted after a push changed boards (consumed by real-time in phase 5). */
export interface BoardsChanged {
  userId: string;
  boardIds: string[];
}

const APPLIED_OPS_TTL_MS = 30 * 24 * 60 * 60 * 1000;
const CLEANUP_INTERVAL_MS = 24 * 60 * 60 * 1000;

const isUniqueViolation = (error: unknown): boolean =>
  error instanceof Prisma.PrismaClientKnownRequestError &&
  error.code === 'P2002';

type PullKind = Exclude<keyof PullResponseDto, 'cursor' | 'hasMore'>;

interface SyncedRow {
  seq: bigint;
  workspaceId: string;
}

/** Wire shape: server-only columns are dropped (boards keep workspaceId). */
function toWire(
  row: SyncedRow,
  keepWorkspace: boolean,
): Record<string, unknown> {
  const wire: Record<string, unknown> = { ...row };
  delete wire.seq;
  if (!keepWorkspace) delete wire.workspaceId;
  return wire;
}

/**
 * Push/pull sync (docs/sync.md). Each op runs in its own transaction that
 * holds the workspace advisory lock, so within one workspace `seq` order
 * equals commit order and per-workspace cursors never skip a row.
 */
@Injectable()
export class SyncService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(SyncService.name);
  private cleanupTimer?: NodeJS.Timeout;
  readonly boardsChanged = new Subject<BoardsChanged>();

  constructor(private readonly prisma: PrismaService) {}

  onModuleInit(): void {
    this.cleanupTimer = setInterval(() => {
      void this.cleanupAppliedOps();
    }, CLEANUP_INTERVAL_MS);
    this.cleanupTimer.unref();
  }

  onModuleDestroy(): void {
    clearInterval(this.cleanupTimer);
    this.boardsChanged.complete();
  }

  async cleanupAppliedOps(): Promise<void> {
    const { count } = await this.prisma.syncAppliedOp.deleteMany({
      where: { createdAt: { lt: new Date(Date.now() - APPLIED_OPS_TTL_MS) } },
    });
    if (count > 0) this.logger.log(`Removed ${String(count)} applied ops`);
  }

  async push(userId: string, ops: PushOpDto[]): Promise<PushResultDto[]> {
    const memberships = await this.prisma.membership.findMany({
      where: { userId, workspace: { deletedAt: null } },
      select: { workspaceId: true },
    });
    const memberOf = new Set(memberships.map((m) => m.workspaceId));

    const results: PushResultDto[] = [];
    const boardIds = new Set<string>();
    for (const op of ops) {
      const { result, boardId } = await this.pushOne(userId, memberOf, op);
      results.push(result);
      if (boardId) boardIds.add(boardId);
    }
    if (boardIds.size > 0) {
      this.boardsChanged.next({ userId, boardIds: [...boardIds] });
    }
    return results;
  }

  private async pushOne(
    userId: string,
    memberOf: Set<string>,
    op: PushOpDto,
  ): Promise<{ result: PushResultDto; boardId?: string }> {
    const { opId } = op;
    const seen = await this.prisma.syncAppliedOp.findUnique({
      where: { opId },
    });
    if (seen) {
      return {
        result:
          seen.userId === userId
            ? {
                opId,
                status: 'duplicate',
                code: (seen.code ?? undefined) as PushResultDto['code'],
                version: seen.version ?? undefined,
              }
            : { opId, status: 'rejected', code: 'SYNC_INVALID_OP' },
      };
    }

    try {
      const applied = await this.prisma.$transaction(async (tx) => {
        const result = await this.apply(tx, userId, memberOf, op);
        await tx.syncAppliedOp.create({
          data: { opId, userId, status: 'applied', version: result.version },
        });
        return result;
      });
      return {
        result: { opId, status: 'applied', version: applied.version },
        boardId: applied.boardId,
      };
    } catch (error) {
      if (error instanceof SyncRejection) {
        await this.prisma.syncAppliedOp.createMany({
          data: [{ opId, userId, status: 'rejected', code: error.code }],
          skipDuplicates: true,
        });
        return { result: { opId, status: 'rejected', code: error.code } };
      }
      // The same op pushed concurrently: the other request recorded it.
      if (isUniqueViolation(error)) {
        return { result: { opId, status: 'duplicate' } };
      }
      throw error;
    }
  }

  private async apply(
    tx: Tx,
    userId: string,
    memberOf: Set<string>,
    op: PushOpDto,
  ): Promise<Applied> {
    const handler = HANDLERS[op.entity];
    const lock = async (workspaceId: string): Promise<void> => {
      if (!memberOf.has(workspaceId)) {
        throw new SyncRejection('SYNC_FORBIDDEN');
      }
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext(${workspaceId}))`;
    };

    const existing = await handler.find(tx, op.entityId);
    if (op.operation === 'create' && !existing) {
      const plan = await handler.planCreate(
        tx,
        op.entityId,
        op.payload,
        userId,
      );
      await lock(plan.workspaceId);
      return plan.apply();
    }
    if (!existing) throw new SyncRejection('SYNC_NOT_FOUND');

    // workspaceId never changes, so locking before the re-read is safe.
    await lock(existing.workspaceId);
    const current = await handler.find(tx, op.entityId);
    if (!current) throw new SyncRejection('SYNC_NOT_FOUND');

    if (op.operation === 'delete') {
      if (current.deletedAt) {
        return { version: current.version, boardId: current.boardId };
      }
      return handler.delete(tx, op.entityId, current, userId, new Date());
    }
    if (current.deletedAt) throw new SyncRejection('SYNC_ENTITY_DELETED');
    // A create for an existing id (lost response + new opId) is an update.
    const payload =
      op.operation === 'create'
        ? pick(op.payload, UPDATE_KEYS[op.entity])
        : op.payload;
    return handler.update(tx, op.entityId, payload, current, userId);
  }

  async pull(userId: string, query: PullQueryDto): Promise<PullResponseDto> {
    const { workspaceId } = query;
    const member = await this.prisma.membership.findFirst({
      where: { userId, workspaceId, workspace: { deletedAt: null } },
    });
    if (!member) throw notFound('Workspace');

    const since = BigInt(query.since ?? '0');
    const limit = query.limit ?? DEFAULT_PULL_LIMIT;
    const args = {
      where: { workspaceId, seq: { gt: since } },
      orderBy: { seq: 'asc' as const },
      take: limit + 1,
    };

    // One snapshot for all tables, or a commit between two queries could
    // move the cursor past a row that the earlier query did not see.
    const page = await this.prisma.$transaction(
      async (tx) => ({
        boards: await tx.board.findMany(args),
        columns: await tx.boardColumn.findMany(args),
        cards: await tx.card.findMany(args),
        checklistItems: await tx.checklistItem.findMany(args),
        comments: await tx.comment.findMany(args),
      }),
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );

    // Each table returned its `limit + 1` lowest seqs, so the `limit` lowest
    // across tables are all present.
    const merged = (Object.keys(page) as PullKind[])
      .flatMap((kind) => page[kind].map((row: SyncedRow) => ({ kind, row })))
      .sort((a, b) => (a.row.seq < b.row.seq ? -1 : 1));
    const taken = merged.slice(0, limit);

    const response: PullResponseDto = {
      boards: [],
      columns: [],
      cards: [],
      checklistItems: [],
      comments: [],
      cursor: String(taken.at(-1)?.row.seq ?? since),
      hasMore: merged.length > limit,
    };
    for (const { kind, row } of taken) {
      response[kind].push(toWire(row, kind === 'boards'));
    }
    return response;
  }
}
