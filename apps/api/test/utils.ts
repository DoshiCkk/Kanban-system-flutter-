import { randomUUID } from 'node:crypto';
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
  // Listening once lets supertest and socket clients share one server
  // (supertest would otherwise call listen() per request).
  await app.listen(0);
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

export interface SyncOp {
  opId: string;
  entity: string;
  entityId: string;
  operation: 'create' | 'update' | 'delete';
  payload: Record<string, unknown>;
}

export const syncOp = (
  entity: string,
  operation: SyncOp['operation'],
  entityId: string,
  payload: Record<string, unknown> = {},
): SyncOp => ({ opId: randomUUID(), entity, entityId, operation, payload });

export async function pushOps(
  app: TestApp,
  user: TestUser,
  ops: SyncOp[],
): Promise<{ status: string; code?: string }[]> {
  const res = await request(app.getHttpServer())
    .post('/sync/push')
    .set(...bearer(user))
    .send({ ops })
    .expect(200);
  return (res.body as { results: { status: string; code?: string }[] }).results;
}

/** Alice owns a workspace that Bob joined through an invite. */
export async function createTeam(app: TestApp): Promise<{
  alice: TestUser;
  bob: TestUser;
  workspaceId: string;
}> {
  const http = () => request(app.getHttpServer());
  const alice = await registerUser(app, 'Alice');
  const bob = await registerUser(app, 'Bob');
  const ws = await http()
    .post('/workspaces')
    .set(...bearer(alice))
    .send({ name: 'Team' })
    .expect(201);
  const workspaceId: string = ws.body.id;
  const invite = await http()
    .post(`/workspaces/${workspaceId}/invites`)
    .set(...bearer(alice))
    .expect(201);
  await http()
    .post(`/invites/${invite.body.token as string}/accept`)
    .set(...bearer(bob))
    .expect(200);
  return { alice, bob, workspaceId };
}
