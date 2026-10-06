import { NodeEnv, validateEnv } from './env.validation.js';

describe('validateEnv', () => {
  it('applies defaults and converts types', () => {
    const env = validateEnv({ PORT: '4000' });
    expect(env.PORT).toBe(4000);
    expect(env.NODE_ENV).toBe(NodeEnv.Development);
  });

  it('rejects invalid values', () => {
    expect(() => validateEnv({ PORT: 'abc' })).toThrow(
      /Invalid environment configuration/,
    );
  });
});
