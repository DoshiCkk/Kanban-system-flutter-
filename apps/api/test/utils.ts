import type { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import type { Redis } from 'ioredis';
import request from 'supertest';
import type { App } from 'supertest/types.js';
import { PrismaService } from '../src/prisma/prisma.service.js';
import { REDIS } from '../src/redis/redis.module.js';
import { setupApp } from '../src/setup-app.js';

export type TestApp = INestApplication<App>;

/**
 * Imports AppModule lazily so a suite can tweak process.env first
 * (ConfigModule reads it when app.module.ts is evaluated).
 */
export async function createTestApp(): Promise<TestApp> {
  const { AppModule } = await import('../src/app.module.js');
  const moduleRef = await Test.createTestingModule({
    imports: [AppModule],
  }).compile();
  const app = moduleRef.createNestApplication<INestApplication<App>>();
  setupApp(app);
  await app.init();
  return app;
}

export async function resetState(app: TestApp): Promise<void> {
  const prisma = app.get(PrismaService);
  await prisma.$executeRawUnsafe(
    'TRUNCATE TABLE sync_applied_ops, comments, checklist_items, cards, board_columns, boards, refresh_tokens, invites, memberships, workspaces, users CASCADE',
  );
  await app.get<Redis>(REDIS).flushdb();
}

export interface TestUser {
  id: string;
  email: string;
  accessToken: string;
  refreshToken: string;
}

let counter = 0;

export async function registerUser(
  app: TestApp,
  name = 'User',
): Promise<TestUser> {
  counter += 1;
  const email = `${name.toLowerCase()}${String(counter)}@example.com`;
  const res = await request(app.getHttpServer())
    .post('/auth/register')
    .send({ email, password: 'correct-horse-battery', name })
    .expect(201);
  return {
    id: res.body.user.id,
    email,
    accessToken: res.body.tokens.accessToken,
    refreshToken: res.body.tokens.refreshToken,
  };
}

export const bearer = (user: TestUser): [string, string] => [
  'Authorization',
  `Bearer ${user.accessToken}`,
];
