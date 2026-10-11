import { readFile } from 'node:fs/promises';
import type { Messaging, SendResponse } from 'firebase-admin/messaging';
import type { PushMessage, PushSender } from './push-sender.js';

/** FCM accepts at most 500 messages per sendEach call. */
const BATCH = 500;

/** Error codes meaning the token will never work again. */
const DEAD_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

/** Firebase Cloud Messaging (HTTP v1 via firebase-admin). */
export class FcmPushSender implements PushSender {
  readonly enabled = true;

  constructor(private readonly messaging: Pick<Messaging, 'sendEach'>) {}

  /** Loads firebase-admin only when push is configured. */
  static async fromServiceAccountFile(path: string): Promise<FcmPushSender> {
    const { cert, initializeApp } = await import('firebase-admin/app');
    const { getMessaging } = await import('firebase-admin/messaging');
    const account = JSON.parse(await readFile(path, 'utf8')) as object;
    const app = initializeApp({ credential: cert(account) }, 'flowboard');
    return new FcmPushSender(getMessaging(app));
  }

  async send(messages: PushMessage[]): Promise<string[]> {
    const dead: string[] = [];
    for (let i = 0; i < messages.length; i += BATCH) {
      const batch = messages.slice(i, i + BATCH);
      const { responses } = await this.messaging.sendEach(
        batch.map((m) => ({
          token: m.token,
          notification: { title: m.title, body: m.body },
          data: m.data,
          android: { priority: 'high' as const },
          apns: { payload: { aps: { sound: 'default' } } },
        })),
      );
      responses.forEach((response: SendResponse, index) => {
        const code = response.error?.code;
        if (code && DEAD_TOKEN_CODES.has(code)) dead.push(batch[index].token);
      });
    }
    return dead;
  }
}
