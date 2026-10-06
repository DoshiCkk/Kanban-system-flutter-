import { NodeEnv, validateEnv } from './env.validation.js';

const required = {
  DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
  REDIS_URL: 'redis://localhost:6379/0',
  JWT_ACCESS_SECRET: 'x'.repeat(32),
};

describe('validateEnv', () => {
  it('applies defaults and converts types', () => {
    const env = validateEnv({ ...required, PORT: '4000' });
    expect(env.PORT).toBe(4000);
    expect(env.NODE_ENV).toBe(NodeEnv.Development);
    expect(env.JWT_ACCESS_TTL_SECONDS).toBe(900);
  });

  it('rejects invalid values', () => {
    expect(() => validateEnv({ ...required, PORT: 'abc' })).toThrow(
      /Invalid environment configuration/,
    );
  });

  it('rejects a short JWT secret', () => {
    expect(() =>
      validateEnv({ ...required, JWT_ACCESS_SECRET: 'short' }),
    ).toThrow(/JWT_ACCESS_SECRET/);
  });
});
