import request from 'supertest';
import { createTestApp, resetState, type TestApp } from './utils.js';

describe('Rate limiting (e2e)', () => {
  let app: TestApp;

  beforeAll(async () => {
    // Must be set before AppModule is imported (see createTestApp).
    process.env.THROTTLE_AUTH_LIMIT = '3';
    app = await createTestApp();
    await resetState(app);
  });

  afterAll(async () => {
    await app.close();
  });

  it('limits /auth endpoints per IP via Redis', async () => {
    const attempt = () =>
      request(app.getHttpServer())
        .post('/auth/login')
        .send({ email: 'nobody@example.com', password: 'whatever' });

    for (let i = 0; i < 3; i += 1) {
      expect((await attempt()).status).toBe(401);
    }
    const blocked = await attempt();
    expect(blocked.status).toBe(429);
    expect(blocked.headers['retry-after-auth']).toBeDefined();
  });

  it('does not apply the auth limit to other routes', async () => {
    await request(app.getHttpServer()).get('/health').expect(200);
    await request(app.getHttpServer()).get('/users/me').expect(401);
  });
});
