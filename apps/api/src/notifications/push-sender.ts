import { Logger } from '@nestjs/common';

/** One push to one device. */
export interface PushMessage {
  token: string;
  title: string;
  body: string;
  /** Opened by the app on tap (docs/push.md, "Payload"). */
  data: Record<string, string>;
}

/**
 * Delivery channel behind NotificationsService: FCM when Firebase is
 * configured, otherwise a no-op so the API runs without a Firebase project.
 */
export interface PushSender {
  readonly enabled: boolean;

  /** Sends all messages; returns the tokens the provider rejected as dead. */
  send(messages: PushMessage[]): Promise<string[]>;
}

export const PUSH_SENDER = Symbol('PUSH_SENDER');

export class NoopPushSender implements PushSender {
  private readonly logger = new Logger(NoopPushSender.name);
  readonly enabled = false;

  send(messages: PushMessage[]): Promise<string[]> {
    this.logger.debug(`Push disabled; dropped ${String(messages.length)}`);
    return Promise.resolve([]);
  }
}
