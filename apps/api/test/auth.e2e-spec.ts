import request from 'supertest';
import {
  bearer,
  createTestApp,
  registerUser,
  resetState,
  type TestApp,
} from './utils.js';

describe('Auth (e2e)', () => {
  let app: TestApp;

  beforeAll(async () => {
    app = await createTestApp();
  });

  beforeEach(async () => {
    await resetState(app);
  });

  afterAll(async () => {
    await app.close();
  });

  const http = () => request(app.getHttpServer());

  describe('POST /auth/register', () => {
    it('creates a user, normalizes email and returns tokens', async () => {
      const res = await http()
        .post('/auth/register')
        .send({
          email: '  Aigerim@Example.COM ',
          password: 'correct-horse-battery',
          name: ' Aigerim ',
          locale: 'kk',
        })
        .expect(201);

      expect(res.body.user).toMatchObject({
        email: 'aigerim@example.com',
        name: 'Aigerim',
        locale: 'kk',
      });
      expect(res.body.user).not.toHaveProperty('passwordHash');
      expect(res.body.tokens).toMatchObject({
        accessToken: expect.any(String),
        refreshToken: expect.any(String),
        expiresIn: 900,
      });
    });

    it('rejects a duplicate email with EMAIL_TAKEN', async () => {
      const user = await registerUser(app, 'Dup');
      const res = await http()
        .post('/auth/register')
        .send({
          email: user.email.toUpperCase(),
          password: 'another-password',
          name: 'Dup 2',
        })
        .expect(409);
      expect(res.body.code).toBe('EMAIL_TAKEN');
    });

    it('validates input with VALIDATION_FAILED', async () => {
      const res = await http()
        .post('/auth/register')
        .send({ email: 'not-an-email', password: 'short', name: '' })
        .expect(400);
      expect(res.body.code).toBe('VALIDATION_FAILED');
      const fields = (res.body.details as { field: string }[]).map(
        (d) => d.field,
      );
      expect(fields).toEqual(
        expect.arrayContaining(['email', 'password', 'name']),
      );
    });
  });

  describe('POST /auth/login', () => {
    it('returns tokens for valid credentials', async () => {
      const user = await registerUser(app, 'Login');
      const res = await http()
        .post('/auth/login')
        .send({ email: user.email, password: 'correct-horse-battery' })
        .expect(200);
      expect(res.body.user.id).toBe(user.id);
      expect(res.body.tokens.refreshToken).not.toBe(user.refreshToken);
    });

    it.each([
      ['wrong password', true],
      ['unknown email', false],
    ])('rejects %s with INVALID_CREDENTIALS', async (_case, existing) => {
      const user = await registerUser(app, 'Wrong');
      const res = await http()
        .post('/auth/login')
        .send({
          email: existing ? user.email : 'nobody@example.com',
          password: 'wrong-password',
        })
        .expect(401);
      expect(res.body.code).toBe('INVALID_CREDENTIALS');
    });
  });

  describe('protected routes', () => {
    it('GET /users/me requires a valid access token', async () => {
      const user = await registerUser(app, 'Me');
      await http().get('/users/me').expect(401);
      await http()
        .get('/users/me')
        .set('Authorization', 'Bearer garbage')
        .expect(401);
      const res = await http()
        .get('/users/me')
        .set(...bearer(user))
        .expect(200);
      expect(res.body.email).toBe(user.email);
    });

    it('PATCH /users/me updates name and locale', async () => {
      const user = await registerUser(app, 'Patch');
      const res = await http()
        .patch('/users/me')
        .set(...bearer(user))
        .send({ name: 'New Name', locale: 'ru' })
        .expect(200);
      expect(res.body).toMatchObject({ name: 'New Name', locale: 'ru' });
    });
  });

  describe('POST /auth/refresh', () => {
    it('rotates the refresh token and issues a working access token', async () => {
      const user = await registerUser(app, 'Rotate');
      const res = await http()
        .post('/auth/refresh')
        .send({ refreshToken: user.refreshToken })
        .expect(200);

      expect(res.body.refreshToken).not.toBe(user.refreshToken);
      await http()
        .get('/users/me')
        .set('Authorization', `Bearer ${res.body.accessToken as string}`)
        .expect(200);
    });

    it('detects reuse of a rotated token and revokes the whole family', async () => {
      const user = await registerUser(app, 'Reuse');
      const first = await http()
        .post('/auth/refresh')
        .send({ refreshToken: user.refreshToken })
        .expect(200);

      // Replaying the old token (e.g. stolen) fails...
      const replay = await http()
        .post('/auth/refresh')
        .send({ refreshToken: user.refreshToken })
        .expect(401);
      expect(replay.body.code).toBe('INVALID_REFRESH_TOKEN');

      // ...and also kills the legitimate successor.
      await http()
        .post('/auth/refresh')
        .send({ refreshToken: first.body.refreshToken })
        .expect(401);
    });

    it('rejects an unknown token', async () => {
      await http()
        .post('/auth/refresh')
        .send({ refreshToken: 'does-not-exist' })
        .expect(401);
    });

    it('lets only one of two concurrent rotations win', async () => {
      const user = await registerUser(app, 'Race');
      const results = await Promise.all([
        http().post('/auth/refresh').send({ refreshToken: user.refreshToken }),
        http().post('/auth/refresh').send({ refreshToken: user.refreshToken }),
      ]);
      const statuses = results.map((r) => r.status).sort();
      expect(statuses).toEqual([200, 401]);
    });
  });

  describe('POST /auth/logout', () => {
    it('revokes the session', async () => {
      const user = await registerUser(app, 'Logout');
      await http()
        .post('/auth/logout')
        .send({ refreshToken: user.refreshToken })
        .expect(204);
      await http()
        .post('/auth/refresh')
        .send({ refreshToken: user.refreshToken })
        .expect(401);
    });

    it('does not affect other sessions of the same user', async () => {
      const user = await registerUser(app, 'Multi');
      const second = await http()
        .post('/auth/login')
        .send({ email: user.email, password: 'correct-horse-battery' })
        .expect(200);

      await http()
        .post('/auth/logout')
        .send({ refreshToken: user.refreshToken })
        .expect(204);
      await http()
        .post('/auth/refresh')
        .send({ refreshToken: second.body.tokens.refreshToken })
        .expect(200);
    });
  });
});
