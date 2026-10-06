import { Controller, Get, Inject } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { SkipThrottle } from '@nestjs/throttler';
import {
  HealthCheck,
  HealthCheckService,
  HealthIndicatorService,
  MemoryHealthIndicator,
  PrismaHealthIndicator,
} from '@nestjs/terminus';
import type { Redis } from 'ioredis';
import { Public } from '../auth/auth-user.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { REDIS } from '../redis/redis.module.js';

const HEAP_LIMIT_BYTES = 512 * 1024 * 1024;
const CHECK_TIMEOUT_MS = 1500;

@ApiTags('health')
@Public()
@SkipThrottle()
@Controller('health')
export class HealthController {
  constructor(
    private readonly health: HealthCheckService,
    private readonly memory: MemoryHealthIndicator,
    private readonly prismaIndicator: PrismaHealthIndicator,
    private readonly indicators: HealthIndicatorService,
    private readonly prisma: PrismaService,
    @Inject(REDIS) private readonly redis: Redis,
  ) {}

  @Get()
  @HealthCheck()
  check() {
    return this.health.check([
      () => this.memory.checkHeap('memory_heap', HEAP_LIMIT_BYTES),
      () =>
        this.prismaIndicator
          .pingCheck('database', this.prisma)
          .withTimeout(CHECK_TIMEOUT_MS),
      () =>
        this.indicators
          .check('redis')
          .attempt(async () => {
            await this.redis.ping();
          })
          .withTimeout(CHECK_TIMEOUT_MS),
    ]);
  }
}
