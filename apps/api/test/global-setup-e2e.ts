import { execSync } from 'node:child_process';
import { resolve } from 'node:path';
import { loadTestEnv } from './load-test-env.js';

/** Applies migrations to the test database once per e2e run. */
export default function setup(): void {
  loadTestEnv();
  const url = process.env.DATABASE_URL ?? '';
  if (!url.includes('_test')) {
    throw new Error(`Refusing to run e2e against a non-test database: ${url}`);
  }
  execSync('npx prisma migrate deploy', {
    cwd: resolve(import.meta.dirname, '..'),
    env: process.env,
    stdio: 'pipe',
  });
}
