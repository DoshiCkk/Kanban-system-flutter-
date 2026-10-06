import { HttpException, HttpStatus } from '@nestjs/common';

/** Machine-readable error codes. The mobile app maps them to l10n strings. */
export enum ErrorCode {
  ValidationFailed = 'VALIDATION_FAILED',
  EmailTaken = 'EMAIL_TAKEN',
  InvalidCredentials = 'INVALID_CREDENTIALS',
  InvalidRefreshToken = 'INVALID_REFRESH_TOKEN',
  NotFound = 'NOT_FOUND',
  Forbidden = 'FORBIDDEN',
  Conflict = 'CONFLICT',
  InviteInvalid = 'INVITE_INVALID',
  OwnerRoleLocked = 'OWNER_ROLE_LOCKED',
}

export interface ApiErrorBody {
  statusCode: number;
  code: ErrorCode;
  message: string;
  details?: unknown;
}

export class ApiException extends HttpException {
  constructor(
    status: HttpStatus,
    code: ErrorCode,
    message: string,
    details?: unknown,
  ) {
    const body: ApiErrorBody = { statusCode: status, code, message, details };
    super(body, status);
  }
}

export const notFound = (what = 'Resource'): ApiException =>
  new ApiException(
    HttpStatus.NOT_FOUND,
    ErrorCode.NotFound,
    `${what} not found`,
  );

export const forbidden = (message = 'Insufficient role'): ApiException =>
  new ApiException(HttpStatus.FORBIDDEN, ErrorCode.Forbidden, message);
