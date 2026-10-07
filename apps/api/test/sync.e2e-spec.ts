import { randomUUID } from 'node:crypto';
import request from 'supertest';
import {
  bearer,
  createTestApp,
  registerUser,
  resetState,
  type TestApp,
  type TestUser,
} from './utils.js';

interface Op {
  opId: string;
  entity: string;
  entityId: string;
  operation: 'create' | 'update' | 'delete';
  payload: Record<string, unknown>;
}

interface PushResult {
  opId: string;
  status: 'applied' | 'duplicate' | 'rejected';
  code?: string;
  version?: number;
}

type Row = Record<string, unknown> & { id: string; version: number };

interface PullPage {
  boards: Row[];
  columns: Row[];
  cards: Row[];
  checklistItems: Row[];
  comments: Row[];
  cursor: string;
  hasMore: boolean;
}

const now = () => new Date().toISOString();

const op = (
  entity: string,
  operation: Op['operation'],
  entityId: string,
  payload: Record<string, unknown> = {},
): Op => ({ opId: randomUUID(), entity, entityId, operation, payload });

describe('Sync (e2e)', () => {
  let app: TestApp;
  let alice: TestUser;
  let bob: TestUser;
  let workspaceId: string;

  const http = () => request(app.getHttpServer());

  async function push(user: TestUser, ops: Op[]): Promise<PushResult[]> {
    const res = await http()
      .post('/sync/push')
      .set(...bearer(user))
      .send({ ops })
      .expect(200);
    return (res.body as { results: PushResult[] }).results;
  }

  async function pull(
    user: TestUser,
    since = '0',
    limit?: number,
  ): Promise<PullPage> {
    const res = await http()
      .get('/sync/pull')
      .query({ workspaceId, since, ...(limit ? { limit } : {}) })
      .set(...bearer(user))
      .expect(200);
    return res.body as PullPage;
  }

  /** Board "B" with columns "To do" (a0) and "Done" (a1). */
  async function seedBoard(user: TestUser) {
    const boardId = randomUUID();
    const todo = randomUUID();
    const done = randomUUID();
    const results = await push(user, [
      op('board', 'create', boardId, {
        workspaceId,
        title: 'B',
        templateKey: 'basic',
        createdAt: now(),
      }),
      op('column', 'create', todo, {
        boardId,
        title: 'To do',
        position: 'a0',
        createdAt: now(),
      }),
      op('column', 'create', done, {
        boardId,
        title: 'Done',
        position: 'a1',
        createdAt: now(),
      }),
    ]);
    expect(results.map((r) => r.status)).toEqual([
      'applied',
      'applied',
      'applied',
    ]);
    return { boardId, todo, done };
  }

  async function createCard(
    user: TestUser,
    boardId: string,
    columnId: string,
    title = 'Card',
    position = 'a0',
  ) {
    const id = randomUUID();
    const [result] = await push(user, [
      op('card', 'create', id, {
        boardId,
        columnId,
        title,
        position,
        labels: ['ui'],
        priority: 'high',
        createdAt: now(),
      }),
    ]);
    expect(result.status).toBe('applied');
    return id;
  }

  beforeAll(async () => {
    app = await createTestApp();
  });

  beforeEach(async () => {
    await resetState(app);
    alice = await registerUser(app, 'Alice');
    bob = await registerUser(app, 'Bob');
    const ws = await http()
      .post('/workspaces')
      .set(...bearer(alice))
      .send({ name: 'Team' })
      .expect(201);
    workspaceId = ws.body.id;
    const invite = await http()
      .post(`/workspaces/${workspaceId}/invites`)
      .set(...bearer(alice))
      .expect(201);
    await http()
      .post(`/invites/${invite.body.token as string}/accept`)
      .set(...bearer(bob))
      .expect(200);
  });

  afterAll(async () => {
    await app.close();
  });

  it('round-trips every entity and advances the cursor', async () => {
    const { boardId, todo } = await seedBoard(alice);
    const cardId = await createCard(alice, boardId, todo);
    const itemId = randomUUID();
    const commentId = randomUUID();
    const results = await push(alice, [
      op('checklistItem', 'create', itemId, {
        cardId,
        text: 'Draft',
        done: false,
        position: 'a0',
        createdAt: now(),
      }),
      op('comment', 'create', commentId, {
        cardId,
        text: 'Looks good',
        createdAt: now(),
      }),
    ]);
    expect(results.every((r) => r.status === 'applied')).toBe(true);

    const page = await pull(bob);
    expect(page.boards).toHaveLength(1);
    expect(page.boards[0]).toMatchObject({
      id: boardId,
      workspaceId,
      title: 'B',
      version: 1,
      deletedAt: null,
    });
    expect(page.boards[0]).not.toHaveProperty('seq');
    expect(page.columns.map((c) => c.title).sort()).toEqual(['Done', 'To do']);
    expect(page.columns[0]).not.toHaveProperty('workspaceId');
    expect(page.cards[0]).toMatchObject({
      id: cardId,
      boardId,
      columnId: todo,
      labels: ['ui'],
      priority: 'high',
      description: '',
    });
    expect(page.checklistItems[0]).toMatchObject({ id: itemId, done: false });
    expect(page.comments[0]).toMatchObject({
      id: commentId,
      authorId: alice.id,
    });
    expect(page.hasMore).toBe(false);

    const next = await pull(bob, page.cursor);
    expect(next.cards).toHaveLength(0);
    expect(next.cursor).toBe(page.cursor);
  });

  it('is idempotent by opId', async () => {
    const { boardId, todo } = await seedBoard(alice);
    const create = op('card', 'create', randomUUID(), {
      boardId,
      columnId: todo,
      title: 'Once',
      position: 'a0',
      createdAt: now(),
    });
    expect((await push(alice, [create]))[0]?.status).toBe('applied');
    const [again] = await push(alice, [create]);
    expect(again).toMatchObject({ status: 'duplicate', version: 1 });
    expect((await pull(alice)).cards).toHaveLength(1);
  });

  it('applies a create for an existing id as an update', async () => {
    const { boardId, todo } = await seedBoard(alice);
    const cardId = await createCard(alice, boardId, todo, 'First');
    const [result] = await push(alice, [
      op('card', 'create', cardId, {
        boardId,
        columnId: todo,
        title: 'Second',
        position: 'a0',
        createdAt: now(),
      }),
    ]);
    expect(result).toMatchObject({ status: 'applied', version: 2 });
    const cards = (await pull(alice)).cards;
    expect(cards).toHaveLength(1);
    expect(cards[0]?.title).toBe('Second');
  });

  it('merges concurrent edits field by field (last writer wins)', async () => {
    const { boardId, todo, done } = await seedBoard(alice);
    const cardId = await createCard(alice, boardId, todo);

    await push(alice, [op('card', 'update', cardId, { title: 'Alice' })]);
    await push(bob, [
      op('card', 'update', cardId, { columnId: done, position: 'a0' }),
    ]);
    await push(bob, [op('card', 'update', cardId, { title: 'Bob' })]);

    const card = (await pull(alice)).cards[0];
    expect(card).toMatchObject({
      title: 'Bob',
      columnId: done,
      labels: ['ui'],
      version: 4,
    });
  });

  it('lets deletes win and cascades tombstones', async () => {
    const { boardId, todo, done } = await seedBoard(alice);
    const cardId = await createCard(alice, boardId, todo);
    const otherId = await createCard(alice, boardId, todo, 'Other', 'a1');
    const itemId = randomUUID();
    await push(alice, [
      op('checklistItem', 'create', itemId, {
        cardId,
        text: 'x',
        done: false,
        position: 'a0',
        createdAt: now(),
      }),
    ]);
    const before = await pull(bob);

    await push(alice, [op('column', 'delete', done, {})]);
    const results = await push(bob, [
      // Move into the column Alice deleted.
      op('card', 'update', otherId, { columnId: done, position: 'a0' }),
      op('card', 'delete', cardId),
      op('card', 'delete', cardId),
      op('card', 'update', cardId, { title: 'Too late' }),
      op('checklistItem', 'update', itemId, { done: true }),
    ]);
    expect(results.map((r) => r.code ?? r.status)).toEqual([
      'SYNC_PARENT_DELETED',
      'applied',
      'applied',
      'SYNC_ENTITY_DELETED',
      'SYNC_ENTITY_DELETED',
    ]);

    const changes = await pull(bob, before.cursor);
    expect(changes.columns.map((c) => [c.id, c.deletedAt !== null])).toEqual([
      [done, true],
    ]);
    expect(changes.cards.map((c) => c.id)).toEqual([cardId]);
    expect(changes.cards[0]?.deletedAt).not.toBeNull();
    expect(changes.checklistItems[0]).toMatchObject({
      id: itemId,
      done: false,
    });
    expect(changes.checklistItems[0]?.deletedAt).not.toBeNull();
  });

  it('rejects invalid ops one by one', async () => {
    const { boardId, todo } = await seedBoard(alice);
    const cardId = await createCard(alice, boardId, todo);
    const otherBoard = await seedBoard(alice);
    const results = await push(alice, [
      op('card', 'update', cardId, { version: 99 }),
      op('card', 'update', cardId, { title: '' }),
      op('card', 'update', cardId, { position: 'not a key!' }),
      op('card', 'update', cardId, { columnId: otherBoard.todo }),
      op('card', 'update', randomUUID(), { title: 'Ghost' }),
      op('card', 'update', cardId, { title: 'Valid' }),
    ]);
    expect(results.map((r) => r.code ?? r.status)).toEqual([
      'SYNC_INVALID_OP',
      'SYNC_INVALID_OP',
      'SYNC_INVALID_OP',
      'SYNC_INVALID_OP',
      'SYNC_NOT_FOUND',
      'applied',
    ]);
  });

  it('keeps outsiders out', async () => {
    const { boardId } = await seedBoard(alice);
    const eve = await registerUser(app, 'Eve');
    const results = await push(eve, [
      op('board', 'update', boardId, { title: 'Pwned' }),
      op('board', 'create', randomUUID(), {
        workspaceId,
        title: 'Spam',
        createdAt: now(),
      }),
    ]);
    expect(results.map((r) => r.code)).toEqual([
      'SYNC_FORBIDDEN',
      'SYNC_FORBIDDEN',
    ]);
    await http()
      .get('/sync/pull')
      .query({ workspaceId })
      .set(...bearer(eve))
      .expect(404);
  });

  it('only the author edits a comment', async () => {
    const { boardId, todo } = await seedBoard(alice);
    const cardId = await createCard(alice, boardId, todo);
    const commentId = randomUUID();
    await push(alice, [
      op('comment', 'create', commentId, {
        cardId,
        text: 'Hi',
        createdAt: now(),
      }),
    ]);
    const [result] = await push(bob, [
      op('comment', 'update', commentId, { text: 'Edited' }),
    ]);
    expect(result.code).toBe('SYNC_FORBIDDEN');
  });

  it('pages by seq without losing or repeating rows', async () => {
    const { boardId, todo } = await seedBoard(alice);
    for (let i = 0; i < 5; i += 1) {
      await createCard(
        alice,
        boardId,
        todo,
        `Card ${String(i)}`,
        `a${String(i)}`,
      );
    }
    const seen: string[] = [];
    let cursor = '0';
    let pages = 0;
    for (;;) {
      const page = await pull(bob, cursor, 3);
      pages += 1;
      for (const kind of ['boards', 'columns', 'cards'] as const) {
        seen.push(...page[kind].map((r) => r.id));
      }
      cursor = page.cursor;
      if (!page.hasMore) break;
    }
    // 1 board + 2 columns + 5 cards in pages of 3.
    expect(pages).toBe(3);
    expect(seen).toHaveLength(8);
    expect(new Set(seen).size).toBe(8);
  });

  it('a pull loop racing concurrent pushes still sees every row', async () => {
    const { boardId, todo } = await seedBoard(alice);
    let cursor = (await pull(bob)).cursor;
    const ids: string[] = [];
    const seen = new Set<string>();

    const writers = Array.from({ length: 12 }, (_, i) =>
      createCard(
        i % 2 ? alice : bob,
        boardId,
        todo,
        `C${String(i)}`,
        `a${String(i)}`,
      ).then((id) => ids.push(id)),
    );
    const reader = (async () => {
      while (seen.size < 12) {
        const page = await pull(bob, cursor);
        for (const card of page.cards) seen.add(card.id);
        cursor = page.cursor;
      }
    })();
    await Promise.all(writers);
    await reader;
    expect([...seen].sort()).toEqual([...ids].sort());
  });

  it('validates the envelope', async () => {
    await http()
      .post('/sync/push')
      .set(...bearer(alice))
      .send({ ops: [{ opId: 'nope', entity: 'board' }] })
      .expect(400);
    await http()
      .get('/sync/pull')
      .query({ workspaceId, since: '-1' })
      .set(...bearer(alice))
      .expect(400);
  });
});
