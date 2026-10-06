import { config } from 'dotenv';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';

/** Loads .env.test (or the committed .env.test.example) over process.env. */
export function loadTestEnv(): void {
  const root = resolve(import.meta.dirname, '..');
  const local = resolve(root, '.env.test');
  const path = existsSync(local) ? local : resolve(root, '.env.test.example');
  config({ path, override: true, quiet: true });
}
