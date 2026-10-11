import {
  BadRequestException,
  HttpStatus,
  NotFoundException,
} from '@nestjs/common';
import { ThrottlerException } from '@nestjs/throttler';
import { ApiException, ErrorCode, notFound } from './api-error.js';
import { toErrorBody } from './api-exception.filter.js';

describe('toErrorBody', () => {
  it('keeps ApiException bodies as they are', () => {
    const error = new ApiException(
      HttpStatus.CONFLICT,
      ErrorCode.EmailTaken,
      'Email is taken',
    );
    expect(toErrorBody(error)).toEqual({
      statusCode: 409,
      code: 'EMAIL_TAKEN',
      message: 'Email is taken',
    });
    expect(toErrorBody(notFound('Board')).code).toBe('NOT_FOUND');
  });

  it('gives framework errors a code', () => {
    expect(toErrorBody(new NotFoundException('Cannot GET /x'))).toEqual({
      statusCode: 404,
      code: 'NOT_FOUND',
      message: 'Cannot GET /x',
    });
    expect(toErrorBody(new ThrottlerException()).code).toBe('RATE_LIMITED');
    expect(toErrorBody(new BadRequestException(['a', 'b']))).toEqual({
      statusCode: 400,
      code: 'BAD_REQUEST',
      message: 'a; b',
    });
  });

  it('hides crashes behind a generic 500', () => {
    expect(toErrorBody(new Error('db password is hunter2'))).toEqual({
      statusCode: 500,
      code: 'INTERNAL',
      message: 'Internal server error',
    });
  });
});
