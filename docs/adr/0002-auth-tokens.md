# ADR 0002: Access JWT + rotating opaque refresh tokens

- Status: accepted
- Date: 2026-10-06

## Context
The mobile app must stay signed in for weeks, work offline, and survive a stolen refresh token as well as possible. The spec asks for JWT access + refresh with passport-jwt.

## Decision
- **Access token:** JWT (HS256), 15 min (`JWT_ACCESS_TTL_SECONDS`), payload `{ sub, email }`, verified by passport-jwt. A global `JwtAuthGuard` protects every route; `@Public()` opts out.
- **Refresh token:** opaque 256-bit random string, not a JWT. Only its SHA-256 hash is stored (`refresh_tokens.token_hash`). TTL 30 days.
- **Rotation:** every `/auth/refresh` revokes the presented token and issues a new one in the same `familyId`. The revoke is a conditional update (`WHERE revoked_at IS NULL`), so two concurrent refreshes cannot both succeed.
- **Reuse detection:** presenting an already-revoked token revokes the whole family (likely theft). Logout revokes the family of the presented token; other devices keep their sessions.
- **Passwords:** argon2id (`argon2` package defaults). Login against an unknown email still runs a verify against a dummy hash to equalize timing.
- **Rate limiting:** `@nestjs/throttler` with a Redis storage written in-house (`src/redis/redis-throttler.storage.ts`, atomic Lua script) because `@nest-lab/throttler-storage-redis` does not declare NestJS 12 support. Global limit `THROTTLE_LIMIT`/min and a stricter `auth` throttler `THROTTLE_AUTH_LIMIT`/min on `/auth/*`.
- **Errors:** every error body is `{ statusCode, code, message, details? }`; `code` is a stable machine string the app maps to localized text.

## Mobile side
- Tokens and the cached profile live in `flutter_secure_storage` (Keychain `first_unlock` on iOS, so background sync can read them later).
- `AuthInterceptor` attaches the access token and on `401` performs a **single-flight** refresh: concurrent failing requests share one `/auth/refresh` call, then retry. A request that failed with an already-replaced token is retried with the current one without refreshing again.
- If the refresh token is rejected, the session is cleared and the router sends the user to login with a "session expired" notice. Network errors during refresh keep the session (offline-first).
- Startup restores the session from secure storage without a network call.

## Consequences
- Refresh tokens are single-use: a client that loses the refresh response (e.g. app killed mid-request) will be signed out on the next refresh. Acceptable for MVP; a short grace window can be added later (see backlog).
