import { Logger, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { EnvironmentVariables } from '../config/env.validation.js';
import { SyncModule } from '../sync/sync.module.js';
import { DevicesController } from './devices.controller.js';
import { FcmPushSender } from './fcm-push-sender.js';
import { NotificationsService } from './notifications.service.js';
import { NoopPushSender, PUSH_SENDER, type PushSender } from './push-sender.js';

/** FCM when a service account is configured; otherwise push is off. */
export async function createPushSender(
  config: ConfigService<EnvironmentVariables, true>,
): Promise<PushSender> {
  const file = config.get('FIREBASE_SERVICE_ACCOUNT_FILE', { infer: true });
  if (!file) return new NoopPushSender();
  try {
    return await FcmPushSender.fromServiceAccountFile(file);
  } catch (error) {
    // A broken key must not take the API down; push just stays off.
    new Logger('NotificationsModule').error(
      `Could not load the Firebase service account from ${file}`,
      error,
    );
    return new NoopPushSender();
  }
}

@Module({
  imports: [SyncModule],
  controllers: [DevicesController],
  providers: [
    NotificationsService,
    {
      provide: PUSH_SENDER,
      inject: [ConfigService],
      useFactory: createPushSender,
    },
  ],
})
export class NotificationsModule {}
