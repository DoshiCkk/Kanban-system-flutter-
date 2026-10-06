import {
  HttpStatus,
  INestApplication,
  ValidationError,
  ValidationPipe,
} from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { ApiException, ErrorCode } from './common/api-error.js';

const flattenErrors = (
  errors: ValidationError[],
  parent = '',
): { field: string; constraints: string[] }[] =>
  errors.flatMap((error) => {
    const field = parent ? `${parent}.${error.property}` : error.property;
    const own = error.constraints
      ? [{ field, constraints: Object.keys(error.constraints) }]
      : [];
    return [...own, ...flattenErrors(error.children ?? [], field)];
  });

/** Shared app configuration for main.ts and e2e tests. */
export function setupApp(app: INestApplication): void {
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      exceptionFactory: (errors) =>
        new ApiException(
          HttpStatus.BAD_REQUEST,
          ErrorCode.ValidationFailed,
          'Validation failed',
          flattenErrors(errors),
        ),
    }),
  );
  app.enableShutdownHooks();
}

export function setupSwagger(app: INestApplication): void {
  const config = new DocumentBuilder()
    .setTitle('FlowBoard API')
    .setDescription(
      'Mobile-first Kanban backend. Errors have the shape ' +
        '`{ statusCode, code, message, details? }`.',
    )
    .setVersion('0.2.0')
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('docs', app, document);
}
