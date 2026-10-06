# FlowBoard — project rules

Mobile-first, offline-first Kanban for small teams. Monorepo:
`apps/mobile` (Flutter, Android + iOS only), `apps/api` (NestJS), `docker-compose.yml` (Postgres, Redis), `docs/`.

## Workflow
- Work phase by phase (see `docs/architecture.md`). After each phase: lint + tests green, commit, short report, then STOP and wait for "го".
- Ask when a requirement is contradictory or unclear — do not guess.
- Every TODO in code must have an entry in `docs/backlog.md`.
- Conventional Commits, small commits.
- Dev machine is Windows: all commands in docs must work in PowerShell. iOS is not built locally, but code must stay iOS-compatible (guard platform-specific APIs).
- Verify any new dependency exists and is maintained (pub.dev / npm) and use the latest stable version compatible with the toolchain.
- Never commit secrets: only `.env.example` files.

## Mobile (`apps/mobile`)
- Feature-first Clean Architecture: `lib/features/<feature>/{data,domain,presentation}`, shared code in `lib/core/{config,db,network,sync,di,theme,l10n,router}`.
- Data flow: UI → Bloc/Cubit → Repository → (Drift + SyncEngine). Widgets never call the network or the DB directly.
- State: flutter_bloc. DI: get_it (`lib/core/di/injector.dart`). Routing: go_router (`lib/core/router/app_router.dart`), navigate by route name.
- **No hardcoded user-facing strings.** Add keys to `lib/core/l10n/arb/app_en.arb` (with `@key` description) and translate in `app_ru.arb` and `app_kk.arb`. Access via `context.l10n`.
- Colors only from `Theme.of(context).colorScheme` / `AppColors`. Tap targets ≥ 48dp, primary actions in the lower half of the screen.
- API base URL comes from `--dart-define=API_BASE_URL` (`AppConfig`); never hardcode it.
- Lints: `very_good_analysis`. Code and comments in English.
- Models: `@freezed` + `json_serializable`; generated `*.freezed.dart` / `*.g.dart` are committed. Regenerate with Flutter's own Dart: `& D:\Devtools\flutter\bin\dart.bat run build_runner build --delete-conflicting-outputs` (the `dart` on PATH on this machine is a standalone SDK).
- Network: repositories call Dio and wrap errors with `guardApi` → `ApiException(ApiErrorCode)`; UI maps codes via `l10n.apiError(code)`. Auth endpoints pass `Options(extra: {AuthExtra.skipAuth: true})`.
- Screen cubits are created in `app_router.dart` from get_it; widgets never call get_it.

Checks (run from `apps/mobile`):
```powershell
flutter gen-l10n; dart format --set-exit-if-changed lib test; flutter analyze; flutter test
```

## API (`apps/api`)
- NestJS, TypeScript strict, ESM (`.js` suffix in relative imports).
- One Nest module per feature under `src/<feature>/`. DTOs validated with class-validator, documented with @nestjs/swagger.
- Env is validated in `src/config/env.validation.ts`; add new variables there and to `.env.example` and `.env.test.example`.
- Prisma 7 (`prisma-client` generator → `src/generated/prisma`, not committed; `postinstall` generates it). DB URL lives in `prisma.config.ts`.
- All routes require JWT unless `@Public()`. Workspace routes use `WorkspaceMemberGuard` + `@WorkspaceRoles(...)`; non-members get 404.
- Throw `ApiException(status, ErrorCode.X, message)` — never bare strings; the mobile app relies on `code`.
- Tests: Vitest (`*.spec.ts` unit next to code, `test/*.e2e-spec.ts` e2e on the `flowboard_test` database). See ADR 0001 for why Vitest instead of Jest.

Checks (run from `apps/api`):
```powershell
npm run lint; npm run format:check; npm run typecheck; npm test; npm run test:e2e
```

## Sync invariants (details in `docs/sync.md`, written in phase 4)
- Client generates UUID v4 ids. Every synced entity has `createdAt, updatedAt, deletedAt, version`.
- Ordering uses fractional index string keys — moving a card updates one row.
- Every local mutation is written to Drift and the outbox in the same transaction.
