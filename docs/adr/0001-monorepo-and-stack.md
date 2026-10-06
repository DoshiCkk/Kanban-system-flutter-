# ADR 0001: Monorepo and base stack

- Status: accepted
- Date: 2026-10-06

## Context
FlowBoard needs a Flutter client (Android + iOS) and a backend with offline sync and real-time updates. Development happens on Windows, delivery in one week.

## Decision
- One repository: `apps/mobile`, `apps/api`, shared `docs/` and `docker-compose.yml`.
- Mobile: Flutter stable, flutter_bloc, go_router, get_it, Drift, dio, gen-l10n (en, ru, kk), Material 3, `very_good_analysis` lints.
- API: NestJS 12 (TypeScript strict), Prisma + PostgreSQL, Redis, Socket.IO.
- Postgres 17 and Redis 7 run in Docker Compose; the API runs on the host during development for a faster edit loop.

### Deviation: Vitest instead of Jest
The original spec asked for Jest. NestJS 12 scaffolds an ESM project with Vitest; Jest's ESM support is still experimental and would require converting the project to CommonJS. Vitest has a Jest-compatible API (`describe/it/expect`), so unit and e2e tests look the same. Agreed with the product owner on 2026-10-06.

The default linter of the scaffold (oxlint) was replaced with eslint + typescript-eslint (`strictTypeChecked`) + prettier as required by the spec.

### Note: very_good_analysis 10.x
`very_good_analysis` 11 requires a newer Dart SDK than the current Flutter stable (3.44.7 / Dart 3.12.2), so 10.3.0 is used. Upgrade when Flutter stable catches up.

## Consequences
- Vitest does not emit `design:type` metadata for un-annotated properties; class-transformer conversions need explicit `@Type()`.
- Generated l10n code lives in `apps/mobile/lib/core/l10n/gen/` and is not committed; `flutter pub get` regenerates it.
