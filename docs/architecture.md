# Architecture

## Overview
```
Flutter app (Android/iOS)                    NestJS API
┌───────────────────────────┐   HTTPS/JSON   ┌─────────────────────┐
│ UI → Bloc → Repository    │ ─────────────► │ REST: auth, sync    │──► PostgreSQL (Prisma)
│          ↓                │                │ Socket.IO gateway   │──► Redis (adapter, rate limit)
│     Drift (SQLite) +      │ ◄───────────── │                     │
│     Outbox → SyncEngine   │   Socket.IO    └─────────────────────┘
└───────────────────────────┘
```
- **Local-first:** the app reads only from Drift and writes to Drift first. The network is a background concern of the SyncEngine (phase 4).
- **Real-time:** the server notifies `board:<id>` rooms after applying changes; clients pull (phase 5).

## Mobile layout
```
lib/
  app.dart, main.dart
  core/
    config/   AppConfig (--dart-define)
    di/       get_it registrations
    l10n/     ARB files (en, ru, kk) + context.l10n
    router/   go_router
    theme/    AppColors, AppTheme (Material 3, light/dark)
    db/ network/ sync/   (phases 2–4)
  features/<feature>/{data,domain,presentation}
```

## API layout
```
src/
  main.ts, app.module.ts, setup-app.ts
  config/   env validation
  health/   GET /health (terminus)
  <feature>/  one Nest module per feature
test/       e2e specs (Vitest + supertest)
```

## Phases
1. Skeleton: monorepo, Docker, API health + Swagger, Flutter shell with router, DI, theme, l10n.
2. Auth and workspaces.
3. Boards locally (Drift, drag-and-drop).
4. Sync (`docs/sync.md` first).
5. Real-time and comments.
6. Push notifications.
7. Polish and CI.
