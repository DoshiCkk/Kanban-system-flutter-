import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { NotificationsService } from '../src/notifications/notifications.service.js';
import {
  PUSH_SENDER,
  type PushMessage,
  type PushSender,
} from '../src/notifications/push-sender.js';
import { PrismaService } from '../src/prisma/prisma.service.js';
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

class RecordingPushSender implements PushSender {
  readonly enabled = true;
  sent: PushMessage[] = [];
  /** Tokens to report as no longer registered. */
  dead = new Set<string>();

  send(messages: PushMessage[]): Promise<string[]> {
    this.sent.push(...messages);
    return Promise.resolve(
      messages.filter((m) => this.dead.has(m.token)).map((m) => m.token),
    );
  }
}

const HOUR = 60 * 60 * 1000;

describe('Notifications (e2e)', () => {
  const push = new RecordingPushSender();
  let app: TestApp;
  let service: NotificationsService;
  let alice: TestUser;
  let bob: TestUser;
  let eve: TestUser;
  let workspaceId: string;
  let boardId: string;
  let todo: string;
  let done: string;

  const http = () => request(app.getHttpServer());

  const registerDevice = (
    user: TestUser,
    token: string,
    locale = 'en',
    platform = 'android',
  ) =>
    http()
      .put('/devices')
      .set(...bearer(user))
      .send({ token, platform, locale });

  /** Pushes ops and waits for the notifications they cause. */
  async function sync(user: TestUser, ops: ReturnType<typeof syncOp>[]) {
    const results = await pushOps(app, user, ops);
    expect(results.every((r) => r.status === 'applied')).toBe(true);
    await service.idle();
  }

  async function createCard(fields: Record<string, unknown> = {}) {
    const id = randomUUID();
    await sync(alice, [
      syncOp('card', 'create', id, {
        boardId,
        columnId: todo,
        title: 'Intro',
        position: 'a0',
        createdAt: new Date().toISOString(),
        ...fields,
      }),
    ]);
    return id;
  }

  beforeAll(async () => {
    app = await createTestApp((builder) =>
      builder.overrideProvider(PUSH_SENDER).useValue(push),
    );
    service = app.get(NotificationsService);
  });

  beforeEach(async () => {
    await resetState(app);
    ({ alice, bob, workspaceId } = await createTeam(app));
    eve = await registerUser(app, 'Eve');
    await registerDevice(alice, 'alice-phone').expect(204);
    await registerDevice(bob, 'bob-phone', 'ru').expect(204);
    await registerDevice(eve, 'eve-phone').expect(204);
    boardId = randomUUID();
    todo = randomUUID();
    done = randomUUID();
    const createdAt = new Date().toISOString();
    await sync(alice, [
      syncOp('board', 'create', boardId, {
        workspaceId,
        title: 'Diploma',
        createdAt,
      }),
      syncOp('column', 'create', todo, {
        boardId,
        title: 'To do',
        position: 'a0',
        createdAt,
      }),
      syncOp('column', 'create', done, {
        boardId,
        title: 'Done',
        position: 'a1',
        createdAt,
      }),
    ]);
    push.sent = [];
    push.dead.clear();
  });

  afterAll(async () => {
    await app.close();
  });

  it('registers, moves and unregisters device tokens', async () => {
    const prisma = app.get(PrismaService);
    const owner = async () =>
      (await prisma.deviceToken.findUnique({ where: { token: 'shared' } }))
        ?.userId;

    await registerDevice(alice, 'shared', 'kk').expect(204);
    expect(await owner()).toBe(alice.id);
    // The device switched accounts.
    await registerDevice(bob, 'shared', 'kk').expect(204);
    expect(await owner()).toBe(bob.id);

    await http()
      .delete('/devices/shared')
      .set(...bearer(alice))
      .expect(204);
    expect(await owner()).toBe(bob.id);
    await http()
      .delete('/devices/shared')
      .set(...bearer(bob))
      .expect(204);
    expect(await owner()).toBeUndefined();

    await registerDevice(alice, 'x', 'en', 'web').expect(400);
    await registerDevice(alice, 'x', 'de').expect(400);
  });

  it('tells the assignee about a new task in their language', async () => {
    const cardId = await createCard();
    await sync(alice, [
      syncOp('card', 'update', cardId, { assigneeId: bob.id }),
    ]);

    expect(push.sent).toEqual([
      {
        token: 'bob-phone',
        title: 'Вам назначена задача',
        body: '«Intro» на доске «Diploma» · от Alice',
        data: { type: 'assigned', workspaceId, boardId, cardId },
      },
    ]);

    // Same assignee again, self-assignment, an outsider: nothing new.
    await sync(alice, [
      syncOp('card', 'update', cardId, {
        title: 'Intro v2',
        assigneeId: bob.id,
      }),
    ]);
    await createCard({ assigneeId: alice.id });
    await createCard({ assigneeId: eve.id });
    expect(push.sent).toHaveLength(1);
  });

  it('notifies people mentioned in a comment once', async () => {
    const cardId = await createCard();
    const commentId = randomUUID();
    await sync(alice, [
      syncOp('comment', 'create', commentId, {
        cardId,
        text: '@Bob   please\nreview, @Eve too',
        mentions: [bob.id, alice.id, eve.id],
        createdAt: new Date().toISOString(),
      }),
    ]);
    expect(push.sent).toEqual([
      expect.objectContaining({
        token: 'bob-phone',
        title: 'Вас упомянули',
        body: 'Alice в «Intro»: @Bob please review, @Eve too',
        data: { type: 'mentioned', workspaceId, boardId, cardId },
      }),
    ]);

    // Editing keeps Bob mentioned: he is not notified again.
    await sync(alice, [
      syncOp('comment', 'update', commentId, {
        text: '@Bob thanks',
        mentions: [bob.id],
      }),
    ]);
    expect(push.sent).toHaveLength(1);
  });

  it('reminds the assignee on the day before the due date', async () => {
    const now = new Date('2026-10-11T04:00:00Z');
    const due = (hours: number) =>
      new Date(now.getTime() + hours * HOUR).toISOString();
    const soon = await createCard({ assigneeId: bob.id, dueDate: due(10) });
    const later = await createCard({ assigneeId: bob.id, dueDate: due(20) });
    await createCard({ assigneeId: bob.id, dueDate: due(1) });
    await createCard({ assigneeId: bob.id, dueDate: due(10), columnId: done });
    const gone = await createCard({ assigneeId: bob.id, dueDate: due(10) });
    await sync(alice, [syncOp('card', 'delete', gone)]);
    push.sent = [];

    expect(await service.sendDueReminders(now)).toBe(1);
    expect(push.sent).toEqual([
      {
        token: 'bob-phone',
        title: 'Срок — завтра',
        body: '«Intro» на доске «Diploma»',
        data: { type: 'dueTomorrow', workspaceId, boardId, cardId: soon },
      },
    ]);
    // Once per card and due date, also when the job runs again.
    expect(await service.sendDueReminders(now)).toBe(0);

    const sixHoursLater = new Date(now.getTime() + 6 * HOUR);
    expect(await service.sendDueReminders(sixHoursLater)).toBe(1);
    expect(push.sent.at(-1)?.data.cardId).toBe(later);
  });

  it('forgets tokens that the push service rejects', async () => {
    push.dead.add('bob-phone');
    await createCard({ assigneeId: bob.id });
    expect(push.sent.map((m) => m.token)).toEqual(['bob-phone']);
    const tokens = await app.get(PrismaService).deviceToken.findMany();
    expect(tokens.map((t) => t.token).sort()).toEqual([
      'alice-phone',
      'eve-phone',
    ]);
  });
});
