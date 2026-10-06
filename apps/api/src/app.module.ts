import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import type { Redis } from 'ioredis';
import { AuthModule } from './auth/auth.module.js';
import { skipUnlessAuthThrottled } from './common/throttle.js';
import {
  type EnvironmentVariables,
  validateEnv,
} from './config/env.validation.js';
import { HealthModule } from './health/health.module.js';
import { PrismaModule } from './prisma/prisma.module.js';
import { RedisThrottlerStorage } from './redis/redis-throttler.storage.js';
import { REDIS, RedisModule } from './redis/redis.module.js';
import { UsersModule } from './users/users.module.js';
import { WorkspacesModule } from './workspaces/workspaces.module.js';

const MINUTE_MS = 60_000;

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      cache: true,
      validate: validateEnv,
    }),
    PrismaModule,
    RedisModule,
    ThrottlerModule.forRootAsync({
      inject: [ConfigService, REDIS],
      useFactory: (
        config: ConfigService<EnvironmentVariables, true>,
        redis: Redis,
      ) => ({
        throttlers: [
          {
            name: 'default',
            ttl: MINUTE_MS,
            limit: config.get('THROTTLE_LIMIT', { infer: true }),
          },
          {
            name: 'auth',
            ttl: MINUTE_MS,
            limit: config.get('THROTTLE_AUTH_LIMIT', { infer: true }),
            skipIf: skipUnlessAuthThrottled,
          },
        ],
        storage: new RedisThrottlerStorage(redis),
      }),
    }),
    HealthModule,
    AuthModule,
    UsersModule,
    WorkspacesModule,
  ],
  providers: [{ provide: APP_GUARD, useClass: ThrottlerGuard }],
})
export class AppModule {}
