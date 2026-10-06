import { createHash, randomBytes } from 'node:crypto';

/** 256-bit URL-safe random token for refresh tokens and invite links. */
export const generateToken = (): string =>
  randomBytes(32).toString('base64url');

/**
 * Tokens are high-entropy, so a fast hash is enough; it only prevents a
 * database leak from exposing usable tokens.
 */
export const hashToken = (token: string): string =>
  createHash('sha256').update(token).digest('hex');
