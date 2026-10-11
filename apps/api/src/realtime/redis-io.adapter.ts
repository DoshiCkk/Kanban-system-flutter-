import type { INestApplication } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { IoAdapter } from '@nestjs/platform-socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import { Redis } from 'ioredis';
import type { Server, ServerOptions } from 'socket.io';
import type { EnvironmentVariables } from '../config/env.validation.js';

/**
 * Socket.IO over a Redis pub/sub adapter, so room broadcasts reach clients
 * connected to any API instance.
 */
export class RedisIoAdapter extends IoAdapter {
  private readonly redisUrl: string;
  private clients?: { pub: Redis; sub: Redis };

  constructor(app: INestApplication) {
    super(app);
    this.redisUrl = app
      .get(ConfigService<EnvironmentVariables, true>)
      .get('REDIS_URL', { infer: true });
  }

  override createIOServer(port: number, options?: ServerOptions): Server {
    const server: Server = super.createIOServer(port, options);
    if (!this.clients) {
      const pub = new Redis(this.redisUrl);
      this.clients = { pub, sub: pub.duplicate() };
    }
    server.adapter(createAdapter(this.clients.pub, this.clients.sub));
    return server;
  }

  override async dispose(): Promise<void> {
    const clients = this.clients;
    this.clients = undefined;
    if (clients) await Promise.all([clients.pub.quit(), clients.sub.quit()]);
  }
}
