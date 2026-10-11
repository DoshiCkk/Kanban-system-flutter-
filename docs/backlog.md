# Backlog

Items deferred from the current phase or out of MVP scope. Every `TODO` in code must reference an entry here.

## Out of MVP (keep the architecture open for them)
- WIP limit enforcement (`Column.wipLimit` exists, logic in v2).
- Analytics: CFD, cycle time.
- Attachments.
- Sign in with Google.
- Workspace ownership transfer and deletion.
- Invite management UI: list and revoke active invite links (`invites.revoked_at` already exists).

## Deferred
- Upgrade `very_good_analysis` to 11.x and `freezed` to 4.x when Flutter stable ships Dart ≥ 3.13.
- Workspaces and members are cached in Drift (network first, cache fallback) since phase 3; workspace mutations still need the network.
- Pinned `drift >=2.34.0 <2.35.0` / `drift_dev 2.34.0`: newer drift_dev needs analyzer ≥ 13, which conflicts with freezed 3.x. Unpin together with the freezed 4.x upgrade.
- Postgres must sort `position` with `COLLATE "C"` (byte order) to match the client's fractional-index ordering (phase 4 schema).
- Drag and drop: auto-scroll a long column vertically while a card is held near its top/bottom edge (horizontal edge paging is done).
- Sync: coalesce outbox ops for the same row before pushing (fewer requests after long offline sessions).
- Sync: boards created before phase 4 (no outbox ops) never reach the server; acceptable because phase 3 was never released.
- Sync: replace the full re-pull after a rejected update with a per-entity fetch if rejections become frequent.
- Sync: offline creation of workspaces (they stay online-only by design, docs/sync.md §1).
- Refresh token grace window: accept the just-rotated token for a few seconds to survive a lost refresh response.
- HTTPS + real domain for release builds (debug uses cleartext to `10.0.2.2`).
- Real-time: disconnect the socket while the app is in the background (battery); today it lives as long as the process.
- Real-time: live updates for the boards list and the members screen (a `workspace:<id>` room). They refresh on the periodic sync for now; only open boards are live.
- Real-time: skip `board:changed` for the socket of the device that pushed (saves one empty pull per push).
- Comments: show an "edited" mark and a comment counter on card tiles.
- Crash reporting (Crashlytics or Sentry): uncaught errors are only logged for now (`core/errors/error_handling.dart`).
- Push: an in-app notifications list (history), per-type mute settings and quiet hours.
- Push: prune device tokens not refreshed for ~270 days (FCM marks them stale); dead tokens reported by FCM are already removed.
- Push: opening a pushed card that has not been pulled yet shows "card not found" until the sync brings it (a fraction of a second online); a loading state would be nicer.
- iOS: the Push Notifications capability, Background Modes and `GoogleService-Info.plist` must be added in Xcode on a Mac (docs/push.md §4.3); the deployment target is already 15.0 for the Firebase SDK. The unsigned build runs only on demand (`ios.yml`).
- Real screenshots for the README (placeholders in `docs/screenshots/`) once the app runs on an emulator.
- Release signing (Android keystore, iOS certificates) and store listings.
- `npm audit` reports high-severity advisories in Prisma 7's own dependencies (`deepmerge-ts`, `mysql2` via `@prisma/config`); the suggested fix is a downgrade to Prisma 6. Recheck on the next Prisma release.
