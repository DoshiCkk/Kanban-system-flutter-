import {
  Inject,
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import type { Subscription } from 'rxjs';
import { PrismaService } from '../prisma/prisma.service.js';
import { type SyncActivity, SyncService } from '../sync/sync.service.js';
import { excerpt, type NotificationType, renderMessage } from './messages.js';
import { PUSH_SENDER, type PushSender } from './push-sender.js';

const MINUTE_MS = 60_000;
const HOUR_MS = 60 * MINUTE_MS;
const REMINDER_INTERVAL_MS = 15 * MINUTE_MS;

/**
 * The app stores a due date as the local midnight that starts the due day.
 * Reminding 15 to 2 hours before it means 09:00–22:00 local time on the day
 * before, in every time zone, without knowing the user's zone.
 */
const REMIND_FROM_MS = 15 * HOUR_MS;
const REMIND_UNTIL_MS = 2 * HOUR_MS;

const cardRef = {
  id: true,
  title: true,
  workspaceId: true,
  boardId: true,
  board: { select: { title: true } },
} as const;

interface CardRef {
  id: string;
  title: string;
  workspaceId: string;
  boardId: string;
  board: { title: string };
}

/**
 * Push notifications (docs/push.md): a task assigned to you, a mention in
 * a comment, a task due tomorrow. Best effort: failures are logged and
 * never affect the sync request that caused them.
 */
@Injectable()
export class NotificationsService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(NotificationsService.name);
  private readonly inFlight = new Set<Promise<void>>();
  private subscription?: Subscription;
  private timer?: NodeJS.Timeout;

  constructor(
    private readonly prisma: PrismaService,
    private readonly sync: SyncService,
    @Inject(PUSH_SENDER) private readonly sender: PushSender,
  ) {}

  onModuleInit(): void {
    if (!this.sender.enabled) {
      this.logger.log(
        'Push notifications are off: FIREBASE_SERVICE_ACCOUNT_FILE is not set',
      );
      return;
    }
    this.subscription = this.sync.activity.subscribe((event) => {
      this.track(this.onActivity(event));
    });
    this.timer = setInterval(() => {
      this.track(this.sendDueReminders().then(() => undefined));
    }, REMINDER_INTERVAL_MS);
    this.timer.unref();
  }

  async onModuleDestroy(): Promise<void> {
    this.subscription?.unsubscribe();
    clearInterval(this.timer);
    await this.idle();
  }

  /** Resolves when every notification in flight has been handled. */
  async idle(): Promise<void> {
    await Promise.allSettled([...this.inFlight]);
  }

  private track(work: Promise<void>): void {
    const tracked = work
      .catch((error: unknown) => {
        this.logger.error('Failed to send a notification', error);
      })
      .finally(() => this.inFlight.delete(tracked));
    this.inFlight.add(tracked);
  }

  private async onActivity({ actorId, activity }: SyncActivity) {
    switch (activity.type) {
      case 'assigned': {
        if (activity.assigneeId === actorId) return;
        const card = await this.prisma.card.findFirst({
          where: { id: activity.cardId, deletedAt: null },
          select: cardRef,
        });
        if (card) {
          await this.deliver('assigned', [activity.assigneeId], card, actorId);
        }
        return;
      }
      case 'mentioned': {
        const comment = await this.prisma.comment.findFirst({
          where: {
            id: activity.commentId,
            deletedAt: null,
            card: { deletedAt: null },
          },
          select: { text: true, card: { select: cardRef } },
        });
        if (!comment) return;
        const others = activity.userIds.filter((id) => id !== actorId);
        await this.deliver(
          'mentioned',
          others,
          comment.card,
          actorId,
          excerpt(comment.text),
        );
      }
    }
  }

  /**
   * Reminds assignees of cards whose due day starts in 2–15 hours. Cards in
   * the last column of a board with several columns count as done ("Done"
   * in the templates). Each (card, due date) pair is
   * claimed in `due_reminders` before sending, so it is reminded once even
   * when several API instances run this job. Returns the number sent.
   */
  async sendDueReminders(now = new Date()): Promise<number> {
    const cards = await this.prisma.card.findMany({
      where: {
        deletedAt: null,
        assigneeId: { not: null },
        dueDate: {
          gt: new Date(now.getTime() + REMIND_UNTIL_MS),
          lte: new Date(now.getTime() + REMIND_FROM_MS),
        },
        board: { deletedAt: null },
        column: { deletedAt: null },
      },
      select: {
        ...cardRef,
        assigneeId: true,
        dueDate: true,
        column: { select: { position: true } },
      },
    });
    if (cards.length === 0) return 0;

    const columns = await this.prisma.boardColumn.groupBy({
      by: ['boardId'],
      where: { boardId: { in: cards.map((c) => c.boardId) }, deletedAt: null },
      _max: { position: true },
      _count: { _all: true },
    });
    const done = new Map(
      columns
        .filter((g) => g._count._all > 1)
        .map((g) => [g.boardId, g._max.position]),
    );
    const open = cards.flatMap(({ assigneeId, dueDate, ...card }) =>
      assigneeId && dueDate && card.column.position !== done.get(card.boardId)
        ? [{ ...card, assigneeId, dueDate }]
        : [],
    );
    if (open.length === 0) return 0;

    const claimed = await this.prisma.dueReminder.createManyAndReturn({
      data: open.map((c) => ({ cardId: c.id, dueDate: c.dueDate })),
      skipDuplicates: true,
      select: { cardId: true },
    });
    const ids = new Set(claimed.map((r) => r.cardId));
    for (const card of open.filter((c) => ids.has(c.id))) {
      await this.deliver('dueTomorrow', [card.assigneeId], card, null);
    }
    return ids.size;
  }

  /** Sends to every device of [userIds] that still belong to the workspace. */
  private async deliver(
    type: NotificationType,
    userIds: string[],
    card: CardRef,
    actorId: string | null,
    text = '',
  ): Promise<void> {
    if (userIds.length === 0) return;
    // assigneeId has no foreign key: never notify outsiders.
    const devices = await this.prisma.deviceToken.findMany({
      where: {
        userId: { in: userIds },
        user: {
          memberships: {
            some: {
              workspaceId: card.workspaceId,
              workspace: { deletedAt: null },
            },
          },
        },
      },
      select: { token: true, locale: true },
    });
    if (devices.length === 0) return;
    const actor = actorId
      ? await this.prisma.user.findUnique({
          where: { id: actorId },
          select: { name: true },
        })
      : null;
    const data = {
      type,
      workspaceId: card.workspaceId,
      boardId: card.boardId,
      cardId: card.id,
    };
    const dead = await this.sender.send(
      devices.map((device) => ({
        token: device.token,
        data,
        ...renderMessage(type, device.locale, {
          actor: actor?.name ?? '',
          card: card.title,
          board: card.board.title,
          text,
        }),
      })),
    );
    if (dead.length > 0) {
      await this.prisma.deviceToken.deleteMany({
        where: { token: { in: dead } },
      });
    }
  }
}
