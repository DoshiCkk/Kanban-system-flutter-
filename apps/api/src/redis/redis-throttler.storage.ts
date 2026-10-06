import type { ThrottlerStorage } from '@nestjs/throttler';
import type { Redis } from 'ioredis';

// Not re-exported from the package root.
type ThrottlerStorageRecord = Awaited<
  ReturnType<ThrottlerStorage['increment']>
>;

// Fixed-window counter with an optional block period, atomic in Redis.
// KEYS[1] = hits key, KEYS[2] = block key
// ARGV[1] = window ms, ARGV[2] = limit, ARGV[3] = block duration ms
// Returns {totalHits, windowTtlMs, isBlocked(0|1), blockTtlMs}
const INCREMENT_SCRIPT = `
local blockTtl = redis.call('PTTL', KEYS[2])
if blockTtl > 0 then
  local hits = tonumber(redis.call('GET', KEYS[1]) or '0')
  return {hits, redis.call('PTTL', KEYS[1]), 1, blockTtl}
end
local hits = redis.call('INCR', KEYS[1])
if hits == 1 then
  redis.call('PEXPIRE', KEYS[1], ARGV[1])
end
local ttl = redis.call('PTTL', KEYS[1])
if hits > tonumber(ARGV[2]) then
  redis.call('SET', KEYS[2], '1', 'PX', ARGV[3])
  return {hits, ttl, 1, tonumber(ARGV[3])}
end
return {hits, ttl, 0, 0}
`;

/**
 * Redis-backed ThrottlerStorage shared by all API instances.
 * Written in-house: @nest-lab/throttler-storage-redis does not declare
 * support for NestJS 12 yet.
 */
export class RedisThrottlerStorage implements ThrottlerStorage {
  constructor(
    private readonly redis: Redis,
    private readonly prefix = 'throttle',
  ) {}

  async increment(
    key: string,
    ttl: number,
    limit: number,
    blockDuration: number,
    throttlerName: string,
  ): Promise<ThrottlerStorageRecord> {
    const base = `${this.prefix}:${throttlerName}:${key}`;
    const [totalHits, ttlMs, blocked, blockMs] = (await this.redis.eval(
      INCREMENT_SCRIPT,
      2,
      `${base}:hits`,
      `${base}:block`,
      ttl,
      limit,
      blockDuration > 0 ? blockDuration : ttl,
    )) as [number, number, number, number];

    // ThrottlerGuard expects seconds, like the in-memory storage.
    return {
      totalHits,
      timeToExpire: Math.max(0, Math.ceil(ttlMs / 1000)),
      isBlocked: blocked === 1,
      timeToBlockExpire: Math.max(0, Math.ceil(blockMs / 1000)),
    };
  }
}
