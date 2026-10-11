import type { ConfigService } from '@nestjs/config';
import type { BatchResponse, Message } from 'firebase-admin/messaging';
import type { EnvironmentVariables } from '../config/env.validation.js';
import { FcmPushSender } from './fcm-push-sender.js';
import { renderMessage } from './messages.js';
import { createPushSender } from './notifications.module.js';
import { NoopPushSender, type PushMessage } from './push-sender.js';

const message = (token: string): PushMessage => ({
  token,
  title: 'Title',
  body: 'Body',
  data: { type: 'assigned', cardId: 'c1' },
});

/** Fake FCM: tokens starting with "dead" are unregistered. */
function fakeMessaging() {
  const calls: Message[][] = [];
  const messaging = {
    sendEach: (batch: Message[]): Promise<BatchResponse> => {
      calls.push(batch);
      const responses = batch.map((m) =>
        'token' in m && m.token.startsWith('dead')
          ? {
              success: false,
              error: { code: 'messaging/registration-token-not-registered' },
            }
          : { success: true, messageId: 'id' },
      );
      return Promise.resolve({
        responses,
        successCount: 0,
        failureCount: 0,
      } as unknown as BatchResponse);
    },
  };
  return { calls, messaging };
}

describe('FcmPushSender', () => {
  it('sends notification messages and reports dead tokens', async () => {
    const { calls, messaging } = fakeMessaging();
    const sender = new FcmPushSender(messaging);
    const dead = await sender.send([message('ok'), message('dead-1')]);
    expect(dead).toEqual(['dead-1']);
    expect(calls[0][0]).toEqual({
      token: 'ok',
      notification: { title: 'Title', body: 'Body' },
      data: { type: 'assigned', cardId: 'c1' },
      android: { priority: 'high' },
      apns: { payload: { aps: { sound: 'default' } } },
    });
  });

  it('sends in batches of 500', async () => {
    const { calls, messaging } = fakeMessaging();
    await new FcmPushSender(messaging).send(
      Array.from({ length: 501 }, (_, i) => message(String(i))),
    );
    expect(calls.map((c) => c.length)).toEqual([500, 1]);
  });
});

describe('createPushSender', () => {
  const config = (file?: string) =>
    ({ get: () => file }) as unknown as ConfigService<
      EnvironmentVariables,
      true
    >;

  it('keeps push off without Firebase or with an unreadable key', async () => {
    expect(await createPushSender(config())).toBeInstanceOf(NoopPushSender);
    const broken = await createPushSender(config('missing-key.json'));
    expect(broken).toBeInstanceOf(NoopPushSender);
    expect(await broken.send([message('t')])).toEqual([]);
  });
});

describe('renderMessage', () => {
  it('speaks Kazakh, Russian and English', () => {
    const args = {
      actor: 'Aigerim',
      card: 'Intro',
      board: 'Diploma',
      text: '',
    };
    expect(renderMessage('dueTomorrow', 'kk', args).title).toBe(
      'Мерзімі — ертең',
    );
    expect(renderMessage('assigned', 'en', args)).toEqual({
      title: 'You have a new task',
      body: 'Aigerim assigned you “Intro” on Diploma',
    });
    expect(renderMessage('mentioned', 'ru', { ...args, text: 'hi' })).toEqual({
      title: 'Вас упомянули',
      body: 'Aigerim в «Intro»: hi',
    });
  });
});
