import request from 'supertest';
import { createTestApp, resetState, type TestApp } from './utils.js';

describe('Error bodies (e2e)', () => {
  let app: TestApp;
  const http = () => request(app.getHttpServer());

  beforeAll(async () => {
    app = await createTestApp();
    // Throttle counters of earlier suites live in Redis.
    await resetState(app);
  });

  afterAll(async () => {
    await app.close();
  });

  it('gives every error the documented shape', async () => {
    const unknown = await http().get('/no-such-route').expect(404);
    expect(unknown.body).toEqual({
      statusCode: 404,
      code: 'NOT_FOUND',
      message: 'Cannot GET /no-such-route',
    });

    const anonymous = await http().get('/workspaces').expect(401);
    expect(anonymous.body).toMatchObject({
      statusCode: 401,
      code: 'UNAUTHORIZED',
    });

    const malformed = await http()
      .post('/auth/login')
      .set('Content-Type', 'application/json')
      .send('{"email":')
      .expect(400);
    expect(malformed.body).toMatchObject({
      statusCode: 400,
      code: 'BAD_REQUEST',
    });

    const invalid = await http().post('/auth/login').send({}).expect(400);
    expect(invalid.body.code).toBe('VALIDATION_FAILED');
  });
});
