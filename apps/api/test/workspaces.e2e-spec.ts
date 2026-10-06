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

describe('Workspaces and invites (e2e)', () => {
  let app: TestApp;
  let alice: TestUser;
  let bob: TestUser;

  const http = () => request(app.getHttpServer());

  beforeAll(async () => {
    app = await createTestApp();
  });

  beforeEach(async () => {
    await resetState(app);
    alice = await registerUser(app, 'Alice');
    bob = await registerUser(app, 'Bob');
  });

  afterAll(async () => {
    await app.close();
  });

  async function createWorkspace(owner: TestUser, name = 'Team') {
    const res = await http()
      .post('/workspaces')
      .set(...bearer(owner))
      .send({ name })
      .expect(201);
    return res.body as { id: string; role: string; memberCount: number };
  }

  async function invite(user: TestUser, workspaceId: string) {
    const res = await http()
      .post(`/workspaces/${workspaceId}/invites`)
      .set(...bearer(user))
      .expect(201);
    return res.body.token as string;
  }

  async function join(user: TestUser, token: string) {
    return http()
      .post(`/invites/${token}/accept`)
      .set(...bearer(user));
  }

  it('creates a workspace with a client-generated id; creator is owner', async () => {
    const id = randomUUID();
    const res = await http()
      .post('/workspaces')
      .set(...bearer(alice))
      .send({ id, name: '  Diploma  ' })
      .expect(201);
    expect(res.body).toMatchObject({
      id,
      name: 'Diploma',
      role: 'owner',
      memberCount: 1,
    });

    // Same id again is a conflict, not a silent overwrite.
    await http()
      .post('/workspaces')
      .set(...bearer(bob))
      .send({ id, name: 'Hijack' })
      .expect(409);
  });

  it('two users end up in one workspace via an invite link', async () => {
    const ws = await createWorkspace(alice);
    const token = await invite(alice, ws.id);

    const preview = await http()
      .get(`/invites/${token}`)
      .set(...bearer(bob))
      .expect(200);
    expect(preview.body).toMatchObject({
      workspaceId: ws.id,
      workspaceName: 'Team',
      alreadyMember: false,
    });

    const accepted = await join(bob, token);
    expect(accepted.status).toBe(200);
    expect(accepted.body).toMatchObject({
      id: ws.id,
      role: 'member',
      memberCount: 2,
    });

    // Accepting again is idempotent.
    expect((await join(bob, token)).body.role).toBe('member');

    for (const user of [alice, bob]) {
      const members = await http()
        .get(`/workspaces/${ws.id}/members`)
        .set(...bearer(user))
        .expect(200);
      expect(
        (members.body as { user: { id: string }; role: string }[]).map((m) => [
          m.user.id,
          m.role,
        ]),
      ).toEqual([
        [alice.id, 'owner'],
        [bob.id, 'member'],
      ]);
    }

    const bobList = await http()
      .get('/workspaces')
      .set(...bearer(bob))
      .expect(200);
    expect(bobList.body).toHaveLength(1);
  });

  it('hides workspaces from non-members with 404', async () => {
    const ws = await createWorkspace(alice);
    const res = await http()
      .get(`/workspaces/${ws.id}`)
      .set(...bearer(bob))
      .expect(404);
    expect(res.body.code).toBe('NOT_FOUND');
    await http()
      .get('/workspaces/not-a-uuid')
      .set(...bearer(alice))
      .expect(404);
  });

  it('rejects invalid invite tokens', async () => {
    const res = await join(bob, 'bogus-token');
    expect(res.status).toBe(404);
    expect(res.body.code).toBe('INVITE_INVALID');
  });

  describe('roles', () => {
    let wsId: string;

    beforeEach(async () => {
      wsId = (await createWorkspace(alice)).id;
      await join(bob, await invite(alice, wsId));
    });

    it('members cannot invite or rename', async () => {
      await http()
        .post(`/workspaces/${wsId}/invites`)
        .set(...bearer(bob))
        .expect(403);
      await http()
        .patch(`/workspaces/${wsId}`)
        .set(...bearer(bob))
        .send({ name: 'Mine' })
        .expect(403);
    });

    it('owner promotes to admin; admin can invite but not change roles', async () => {
      await http()
        .patch(`/workspaces/${wsId}/members/${bob.id}`)
        .set(...bearer(alice))
        .send({ role: 'admin' })
        .expect(200);

      await invite(bob, wsId);
      await http()
        .patch(`/workspaces/${wsId}/members/${alice.id}`)
        .set(...bearer(bob))
        .send({ role: 'member' })
        .expect(403);
    });

    it('owner role cannot be assigned or changed', async () => {
      await http()
        .patch(`/workspaces/${wsId}/members/${bob.id}`)
        .set(...bearer(alice))
        .send({ role: 'owner' })
        .expect(400);
      const res = await http()
        .patch(`/workspaces/${wsId}/members/${alice.id}`)
        .set(...bearer(alice))
        .send({ role: 'member' })
        .expect(403);
      expect(res.body.code).toBe('OWNER_ROLE_LOCKED');
    });

    it('admin removes members, not the owner; members can leave', async () => {
      await http()
        .patch(`/workspaces/${wsId}/members/${bob.id}`)
        .set(...bearer(alice))
        .send({ role: 'admin' })
        .expect(200);
      const carol = await registerUser(app, 'Carol');
      await join(carol, await invite(bob, wsId));

      await http()
        .delete(`/workspaces/${wsId}/members/${alice.id}`)
        .set(...bearer(bob))
        .expect(403);
      await http()
        .delete(`/workspaces/${wsId}/members/${carol.id}`)
        .set(...bearer(bob))
        .expect(204);

      // Bob leaves on his own.
      await http()
        .delete(`/workspaces/${wsId}/members/${bob.id}`)
        .set(...bearer(bob))
        .expect(204);
      await http()
        .get(`/workspaces/${wsId}`)
        .set(...bearer(bob))
        .expect(404);
    });
  });
});
