import type { Prisma } from '../generated/prisma/client.js';
import type { SyncEntity, SyncRejectCode } from './sync.dto.js';
import {
  BoardCreate,
  BoardUpdate,
  CardCreate,
  CardUpdate,
  ChecklistItemCreate,
  ChecklistItemUpdate,
  ColumnCreate,
  ColumnUpdate,
  CommentCreate,
  CommentUpdate,
  parsePayload,
} from './sync.payloads.js';

export type Tx = Prisma.TransactionClient;
type Payload = Record<string, unknown>;

/** Permanent rejection of one op (docs/sync.md §5). */
export class SyncRejection extends Error {
  constructor(readonly code: SyncRejectCode) {
    super(code);
  }
}

const reject = (code: SyncRejectCode): never => {
  throw new SyncRejection(code);
};

function parse<T extends object>(cls: new () => T, payload: Payload): T {
  return parsePayload(cls, payload) ?? reject('SYNC_INVALID_OP');
}

const toDate = (value: string | null | undefined): Date | null | undefined =>
  value == null ? value : new Date(value);

/** State of an existing row needed to authorize and apply an op. */
export interface Current {
  workspaceId: string;
  boardId: string;
  deletedAt: Date | null;
  version: number;
  authorId?: string;
}

export interface Applied {
  version: number;
  boardId: string;
}

export interface CreatePlan {
  /** Workspace to authorize and lock. */
  workspaceId: string;
  /** Runs after the workspace lock; re-checks the parent. */
  apply: () => Promise<Applied>;
}

export interface EntityHandler {
  find(tx: Tx, id: string): Promise<Current | null>;
  planCreate(
    tx: Tx,
    id: string,
    payload: Payload,
    userId: string,
  ): Promise<CreatePlan>;
  update(
    tx: Tx,
    id: string,
    payload: Payload,
    current: Current,
    userId: string,
  ): Promise<Applied>;
  delete(
    tx: Tx,
    id: string,
    current: Current,
    userId: string,
    now: Date,
  ): Promise<Applied>;
}

const alive = { deletedAt: null };

// Cascades (delete wins): children get a tombstone and a new seq.

async function deleteCardChildren(
  tx: Tx,
  where: Prisma.CardWhereInput,
  now: Date,
): Promise<void> {
  await tx.checklistItem.updateMany({
    where: { ...alive, card: where },
    data: { deletedAt: now },
  });
  await tx.comment.updateMany({
    where: { ...alive, card: where },
    data: { deletedAt: now },
  });
}

const boards: EntityHandler = {
  async find(tx, id) {
    const row = await tx.board.findUnique({
      where: { id },
      select: { workspaceId: true, deletedAt: true, version: true },
    });
    return row && { ...row, boardId: id };
  },

  planCreate(tx, id, payload) {
    const p = parse(BoardCreate, payload);
    return Promise.resolve({
      // Membership of this workspace is checked by the caller.
      workspaceId: p.workspaceId,
      apply: async () => {
        const row = await tx.board.create({
          data: {
            id,
            workspaceId: p.workspaceId,
            title: p.title,
            templateKey: p.templateKey ?? null,
            createdAt: new Date(p.createdAt),
          },
          select: { version: true },
        });
        return { version: row.version, boardId: id };
      },
    });
  },

  async update(tx, id, payload) {
    const p = parse(BoardUpdate, payload);
    const row = await tx.board.update({
      where: { id },
      data: { title: p.title },
      select: { version: true },
    });
    return { version: row.version, boardId: id };
  },

  async delete(tx, id, _current, _userId, now) {
    await deleteCardChildren(tx, { boardId: id }, now);
    await tx.card.updateMany({
      where: { ...alive, boardId: id },
      data: { deletedAt: now },
    });
    await tx.boardColumn.updateMany({
      where: { ...alive, boardId: id },
      data: { deletedAt: now },
    });
    const row = await tx.board.update({
      where: { id },
      data: { deletedAt: now },
      select: { version: true },
    });
    return { version: row.version, boardId: id };
  },
};

const columns: EntityHandler = {
  find(tx, id) {
    return tx.boardColumn.findUnique({
      where: { id },
      select: {
        workspaceId: true,
        boardId: true,
        deletedAt: true,
        version: true,
      },
    });
  },

  async planCreate(tx, id, payload) {
    const p = parse(ColumnCreate, payload);
    const board = await tx.board.findUnique({
      where: { id: p.boardId },
      select: { workspaceId: true },
    });
    if (!board) return reject('SYNC_PARENT_DELETED');
    return {
      workspaceId: board.workspaceId,
      apply: async () => {
        const parent = await tx.board.findFirst({
          where: { id: p.boardId, ...alive },
        });
        if (!parent) reject('SYNC_PARENT_DELETED');
        const row = await tx.boardColumn.create({
          data: {
            id,
            workspaceId: board.workspaceId,
            boardId: p.boardId,
            title: p.title,
            position: p.position,
            wipLimit: p.wipLimit ?? null,
            createdAt: new Date(p.createdAt),
          },
          select: { version: true },
        });
        return { version: row.version, boardId: p.boardId };
      },
    };
  },

  async update(tx, id, payload, current) {
    const p = parse(ColumnUpdate, payload);
    const row = await tx.boardColumn.update({
      where: { id },
      data: { title: p.title, position: p.position, wipLimit: p.wipLimit },
      select: { version: true },
    });
    return { version: row.version, boardId: current.boardId };
  },

  async delete(tx, id, current, _userId, now) {
    await deleteCardChildren(tx, { columnId: id }, now);
    await tx.card.updateMany({
      where: { ...alive, columnId: id },
      data: { deletedAt: now },
    });
    const row = await tx.boardColumn.update({
      where: { id },
      data: { deletedAt: now },
      select: { version: true },
    });
    return { version: row.version, boardId: current.boardId };
  },
};

const cards: EntityHandler = {
  find(tx, id) {
    return tx.card.findUnique({
      where: { id },
      select: {
        workspaceId: true,
        boardId: true,
        deletedAt: true,
        version: true,
      },
    });
  },

  async planCreate(tx, id, payload) {
    const p = parse(CardCreate, payload);
    const column = await tx.boardColumn.findUnique({
      where: { id: p.columnId },
      select: { workspaceId: true, boardId: true },
    });
    if (!column) return reject('SYNC_PARENT_DELETED');
    if (column.boardId !== p.boardId) return reject('SYNC_INVALID_OP');
    return {
      workspaceId: column.workspaceId,
      apply: async () => {
        const parent = await tx.boardColumn.findFirst({
          where: { id: p.columnId, ...alive },
        });
        if (!parent) reject('SYNC_PARENT_DELETED');
        const row = await tx.card.create({
          data: {
            id,
            workspaceId: column.workspaceId,
            boardId: p.boardId,
            columnId: p.columnId,
            title: p.title,
            description: p.description,
            assigneeId: p.assigneeId ?? null,
            dueDate: toDate(p.dueDate) ?? null,
            priority: p.priority,
            labels: p.labels,
            position: p.position,
            createdAt: new Date(p.createdAt),
          },
          select: { version: true },
        });
        return { version: row.version, boardId: p.boardId };
      },
    };
  },

  async update(tx, id, payload, current) {
    const p = parse(CardUpdate, payload);
    if (p.columnId !== undefined) {
      const target = await tx.boardColumn.findUnique({
        where: { id: p.columnId },
        select: { boardId: true, deletedAt: true },
      });
      if (!target || target.deletedAt) reject('SYNC_PARENT_DELETED');
      // Moving across boards is out of MVP scope.
      if (target?.boardId !== current.boardId) reject('SYNC_INVALID_OP');
    }
    const row = await tx.card.update({
      where: { id },
      data: {
        columnId: p.columnId,
        title: p.title,
        description: p.description,
        assigneeId: p.assigneeId,
        dueDate: toDate(p.dueDate),
        priority: p.priority,
        labels: p.labels,
        position: p.position,
      },
      select: { version: true },
    });
    return { version: row.version, boardId: current.boardId };
  },

  async delete(tx, id, current, _userId, now) {
    await deleteCardChildren(tx, { id }, now);
    const row = await tx.card.update({
      where: { id },
      data: { deletedAt: now },
      select: { version: true },
    });
    return { version: row.version, boardId: current.boardId };
  },
};

/** Resolves the card a child row is attached to. */
async function parentCard(
  tx: Tx,
  cardId: string,
): Promise<{ workspaceId: string; boardId: string }> {
  const card = await tx.card.findUnique({
    where: { id: cardId },
    select: { workspaceId: true, boardId: true },
  });
  return card ?? reject('SYNC_PARENT_DELETED');
}

async function assertCardAlive(tx: Tx, cardId: string): Promise<void> {
  const card = await tx.card.findFirst({ where: { id: cardId, ...alive } });
  if (!card) reject('SYNC_PARENT_DELETED');
}

const checklistItems: EntityHandler = {
  async find(tx, id) {
    const row = await tx.checklistItem.findUnique({
      where: { id },
      select: {
        workspaceId: true,
        deletedAt: true,
        version: true,
        card: { select: { boardId: true } },
      },
    });
    return row && { ...row, boardId: row.card.boardId };
  },

  async planCreate(tx, id, payload) {
    const p = parse(ChecklistItemCreate, payload);
    const card = await parentCard(tx, p.cardId);
    return {
      workspaceId: card.workspaceId,
      apply: async () => {
        await assertCardAlive(tx, p.cardId);
        const row = await tx.checklistItem.create({
          data: {
            id,
            workspaceId: card.workspaceId,
            cardId: p.cardId,
            text: p.text,
            done: p.done,
            position: p.position,
            createdAt: new Date(p.createdAt),
          },
          select: { version: true },
        });
        return { version: row.version, boardId: card.boardId };
      },
    };
  },

  async update(tx, id, payload, current) {
    const p = parse(ChecklistItemUpdate, payload);
    const row = await tx.checklistItem.update({
      where: { id },
      data: { text: p.text, done: p.done, position: p.position },
      select: { version: true },
    });
    return { version: row.version, boardId: current.boardId };
  },

  async delete(tx, id, current, _userId, now) {
    const row = await tx.checklistItem.update({
      where: { id },
      data: { deletedAt: now },
      select: { version: true },
    });
    return { version: row.version, boardId: current.boardId };
  },
};

const comments: EntityHandler = {
  async find(tx, id) {
    const row = await tx.comment.findUnique({
      where: { id },
      select: {
        workspaceId: true,
        deletedAt: true,
        version: true,
        authorId: true,
        card: { select: { boardId: true } },
      },
    });
    return row && { ...row, boardId: row.card.boardId };
  },

  async planCreate(tx, id, payload, userId) {
    const p = parse(CommentCreate, payload);
    const card = await parentCard(tx, p.cardId);
    return {
      workspaceId: card.workspaceId,
      apply: async () => {
        await assertCardAlive(tx, p.cardId);
        const row = await tx.comment.create({
          data: {
            id,
            workspaceId: card.workspaceId,
            cardId: p.cardId,
            authorId: userId,
            text: p.text,
            mentions: p.mentions ?? [],
            createdAt: new Date(p.createdAt),
          },
          select: { version: true },
        });
        return { version: row.version, boardId: card.boardId };
      },
    };
  },

  async update(tx, id, payload, current, userId) {
    if (current.authorId !== userId) reject('SYNC_FORBIDDEN');
    const p = parse(CommentUpdate, payload);
    const row = await tx.comment.update({
      where: { id },
      data: { text: p.text },
      select: { version: true },
    });
    return { version: row.version, boardId: current.boardId };
  },

  async delete(tx, id, current, userId, now) {
    if (current.authorId !== userId) reject('SYNC_FORBIDDEN');
    const row = await tx.comment.update({
      where: { id },
      data: { deletedAt: now },
      select: { version: true },
    });
    return { version: row.version, boardId: current.boardId };
  },
};

export const HANDLERS: Record<SyncEntity, EntityHandler> = {
  board: boards,
  column: columns,
  card: cards,
  checklistItem: checklistItems,
  comment: comments,
};
