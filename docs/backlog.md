# Backlog

Items deferred from the current phase or out of MVP scope. Every `TODO` in code must reference an entry here.

## Out of MVP (keep the architecture open for them)
- WIP limit enforcement (`Column.wipLimit` exists, logic in v2).
- Analytics: CFD, cycle time.
- Attachments.
- Sign in with Google.

## Deferred
- `/health` checks only process memory; add Postgres and Redis indicators in phase 2 together with Prisma.
- Upgrade `very_good_analysis` to 11.x when Flutter stable ships a compatible Dart SDK.
