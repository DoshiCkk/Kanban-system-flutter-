import {
  type ArgumentsHost,
  Catch,
  type ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import type { Response } from 'express';
import { type ApiErrorBody, ErrorCode } from './api-error.js';

const STATUS_CODES: Partial<Record<number, ErrorCode>> = {
  [HttpStatus.UNAUTHORIZED]: ErrorCode.Unauthorized,
  [HttpStatus.FORBIDDEN]: ErrorCode.Forbidden,
  [HttpStatus.NOT_FOUND]: ErrorCode.NotFound,
  [HttpStatus.CONFLICT]: ErrorCode.Conflict,
  [HttpStatus.TOO_MANY_REQUESTS]: ErrorCode.RateLimited,
};

const hasCode = (body: unknown): body is ApiErrorBody =>
  typeof body === 'object' && body !== null && 'code' in body;

/** Message of a framework HttpException (string or class-validator list). */
function messageOf(exception: HttpException): string {
  const body = exception.getResponse();
  if (typeof body === 'string') return body;
  const { message } = body as { message?: unknown };
  if (Array.isArray(message)) return message.join('; ');
  return typeof message === 'string' ? message : exception.message;
}

/** Maps any error to the documented `{ statusCode, code, message }` body. */
export function toErrorBody(exception: unknown): ApiErrorBody {
  if (!(exception instanceof HttpException)) {
    // Never leak internals; the filter logs the real error.
    return {
      statusCode: HttpStatus.INTERNAL_SERVER_ERROR,
      code: ErrorCode.Internal,
      message: 'Internal server error',
    };
  }
  const body = exception.getResponse();
  if (hasCode(body)) return body;
  const statusCode = exception.getStatus();
  const code =
    STATUS_CODES[statusCode] ??
    (statusCode >= 500 ? ErrorCode.Internal : ErrorCode.BadRequest);
  return { statusCode, code, message: messageOf(exception) };
}

/**
 * Global HTTP filter: ApiExceptions pass through unchanged; framework
 * errors (unknown route, throttling, malformed JSON) and crashes get the
 * same shape, so the app can always switch on `code`. Not applied to
 * sockets: Nest uses gateway filters there.
 */
@Catch()
export class ApiExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(ApiExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const body = toErrorBody(exception);
    if (body.statusCode >= 500) {
      this.logger.error(
        exception instanceof Error ? exception.stack : String(exception),
      );
    }
    const response = host.switchToHttp().getResponse<Response>();
    if (response.headersSent) return;
    response.status(body.statusCode).json(body);
  }
}
