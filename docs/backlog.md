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
- Workspaces are online-only in phase 2; cache them in Drift together with boards (phase 3–4) so the list opens offline.
- Send the chosen UI language to the server (`PATCH /users/me { locale }`) so push notifications use it (phase 6).
- Refresh token grace window: accept the just-rotated token for a few seconds to survive a lost refresh response.
- HTTPS + real domain for release builds (debug uses cleartext to `10.0.2.2`).
