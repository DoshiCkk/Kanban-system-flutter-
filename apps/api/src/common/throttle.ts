import { ExecutionContext, SetMetadata } from '@nestjs/common';

const AUTH_THROTTLE_KEY = 'flowboard:authThrottle';

/** Applies the stricter `auth` throttler (THROTTLE_AUTH_LIMIT per minute). */
export const AuthThrottle = (): ClassDecorator & MethodDecorator =>
  SetMetadata(AUTH_THROTTLE_KEY, true);

/** `skipIf` for the `auth` throttler: skip routes without @AuthThrottle(). */
export const skipUnlessAuthThrottled = (context: ExecutionContext): boolean =>
  Reflect.getMetadata(AUTH_THROTTLE_KEY, context.getHandler()) !== true &&
  Reflect.getMetadata(AUTH_THROTTLE_KEY, context.getClass()) !== true;
