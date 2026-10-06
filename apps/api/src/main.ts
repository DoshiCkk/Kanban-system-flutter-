import { NestFactory } from '@nestjs/core';
import { ConfigService } from '@nestjs/config';
import { AppModule } from './app.module.js';
import type { EnvironmentVariables } from './config/env.validation.js';
import { setupApp, setupSwagger } from './setup-app.js';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule);
  const config = app.get(ConfigService<EnvironmentVariables, true>);

  app.enableCors({
    origin: config.get('CORS_ORIGIN', { infer: true }) ?? true,
  });
  setupApp(app);
  setupSwagger(app);

  // 0.0.0.0 so the Android emulator can reach the host via 10.0.2.2.
  await app.listen(config.get('PORT', { infer: true }), '0.0.0.0');
}
await bootstrap();
