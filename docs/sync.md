# Sync design

Status: **draft for review** (phase 4). No sync code is written until this document is approved.

## 1. Goals and non-goals

Goals:
- The app works fully offline for boards, columns, cards and checklists. The UI never waits for the network.
- Every change made offline reaches the server once the network returns, even after the app was killed.
- Two devices editing the same board converge to the same state without manual merging.
- Moving a card writes one row (fractional index, see phase 3).
- Sync is idempotent: retries after timeouts or crashes never duplicate data.

Non-goals (MVP):
- Character-level merging of text (no CRDT for descriptions). The last write to a field wins.
- Offline creation of workspaces, invites and membership changes. They stay online REST calls (phase 2); workspaces and members are only cached for reading.
- Syncing comments is part of phase 5; the protocol below already covers the `comments` entity.

## 2. Data model

### Synced entities

| Entity | Parent | Server table | Client table |
|---|---|---|---|
| `board` | workspace | `boards` | `boards` |
| `column` | board | `board_columns` | `board_columns` |
| `card` | column (+ board) | `cards` | `cards` |
| `checklistItem` | card | `checklist_items` | `checklist_items` |
| `comment` (phase 5) | card | `comments` | `comments` |

Every synced row has:

| Field | Set by | Meaning |
|---|---|---|
| `id` | client | UUID v4, generated on the device. The server never changes it. |
| `createdAt` | client | When the row was created on the device. Informational only. |
| `updatedAt` | server | When the server last applied a change. Clients do not use it for conflicts. |
| `deletedAt` | client or server | Soft delete (tombstone). Rows are never hard-deleted while sync needs them. |
| `version` | server | Incremented on every applied change. Used for diagnostics and future optimistic checks, not for conflict resolution in the MVP. |
| `seq` | server only | Global, monotonically increasing number of the last change of this row (see below). |
| `workspaceId` | server only | Denormalized on every server table, so pull can filter by one indexed column. |

`position` columns are fractional-index strings. Postgres sorts them with `COLLATE "C"` (byte order), which matches the client's comparison. Ties are broken by `id` on both sides.

### Change tracking on the server: row `seq` instead of a separate change log

The phase plan said "change_log with a global seq cursor". I propose a compacted variant of it:
- A single Postgres sequence `sync_seq`.
- Every write to a synced row sets `row.seq = nextval('sync_seq')` in the same transaction.
- Tombstones are ordinary rows with `deletedAt` set, so deletes are pulled like any other change.

Why not a separate `change_log` table:
- It grows forever and needs compaction. The row `seq` is the compacted log: only the latest state of each row matters to clients.
- The first sync of a new device (or a newly joined workspace) is the same query as an incremental sync (`seq > 0`). No separate snapshot endpoint.

Trade-off: we lose the history of intermediate values. The activity feed is out of scope, so this is acceptable.

### Commit-order safety

A plain global sequence has a known gap problem:
1. Transaction A takes `seq = 10`.
2. Transaction B takes `seq = 11` and commits first.
3. A client pulls, sees 11 and moves its cursor to 11.
4. A then commits row 10, and that client never sees it.

To prevent this, every push transaction takes `pg_advisory_xact_lock(hashtext(workspaceId))` before writing. Within one workspace, writes are serialized, so `seq` order equals commit order. Cursors are per workspace (§4), so serializing per workspace is enough. Small teams mean low contention.

## 3. Client side: outbox

Rule: **every local mutation writes the entity row and an outbox record in the same Drift transaction.** If the app dies, either both exist or neither does.

Outbox record (table `outbox`, already created in phase 3):

| Column | Meaning |
|---|---|
| `opId` | UUID v4, idempotency key |
| `entity` | `board`, `column`, `card`, `checklistItem`, `comment` |
| `entityId` | Row id |
| `operation` | `create`, `update` or `delete` |
| `payload` | JSON of the **changed fields only** (full row for `create`) |
| `createdAt` | Ordering of ops |
| `attempts` | Failed push attempts, for backoff |

Examples:
- Moving a card writes `update card {columnId, position}`.
- Toggling a checklist item writes `update checklistItem {done}`.
- Deleting a column writes `delete column` plus `delete card` for each card that the local repository soft-deleted with it. The server applies the same cascade itself, so these extra ops are idempotent no-ops there.

Ops are not coalesced in the MVP. Batches are small (a person edits a few cards), and keeping each op makes debugging easier.

`BoardsRepository` / `CardRepository` stay the only writers. The `SyncEngine` is the only reader of the outbox and the only code that talks to `/sync/*`.

## 4. Protocol

All bodies are JSON, camelCase, dates in ISO 8601 UTC. Both endpoints require the JWT. Errors use the existing `{statusCode, code, message}` shape.

### Push: `POST /sync/push`

```json
{
  "ops": [
    {
      "opId": "4f1c…",
      "entity": "card",
      "entityId": "a9e2…",
      "operation": "update",
      "baseVersion": 3,
      "payload": { "columnId": "c2…", "position": "a0V" }
    }
  ]
}
```
- At most 100 ops per request. The client sends them in `createdAt` order.

Response:
```json
{
  "results": [
    { "opId": "4f1c…", "status": "applied", "version": 4 },
    { "opId": "77aa…", "status": "rejected", "code": "SYNC_PARENT_DELETED" }
  ]
}
```

| Status | Meaning | Client action |
|---|---|---|
| `applied` | Change written | Delete op from the outbox |
| `duplicate` | `opId` seen before; the stored result is returned | Delete op from the outbox |
| `rejected` | Permanently invalid (see §5) | Delete op; the next pull restores the server truth |

Server processing:
- Ops are applied **in order, each in its own savepoint**, so one rejected op does not roll back the others.
- Applied `opId`s are stored in `sync_applied_ops(opId PK, userId, status, code, createdAt)` and kept for 30 days. A daily cleanup deletes older rows.
- A whole request failing (network, 5xx, 401 after refresh) is retried as a whole. Idempotency makes that safe.

### Pull: `GET /sync/pull?workspaceId=<id>&since=<seq>&limit=500`

```json
{
  "boards": [ { …full row… } ],
  "columns": [ … ],
  "cards": [ … ],
  "checklistItems": [ … ],
  "comments": [ … ],
  "cursor": "1834",
  "hasMore": false
}
```
- Returns the rows of that workspace with `seq > since`, ordered by `seq`, at most `limit` in total, including tombstones.
- `cursor` is the max `seq` in the response. It is a string, because bigint does not fit safely into JSON numbers.
- The client stores one cursor per workspace in `local_meta` (`sync.cursor.<workspaceId>`) and loops while `hasMore`.
- A non-member gets 404 (existing `WorkspaceMemberGuard`). The client then treats the workspace as lost (§6).

One workspace per request keeps the permission check trivial. A user rarely has more than a handful of workspaces.

## 5. Conflict resolution

The server is the single authority. Order is the order in which the server applies ops, not device clocks, so clock skew does not matter.

1. **Field-level last-writer-wins.** An `update` only touches the fields in its payload.
   - Alice renames a card while Bob moves it: both changes survive.
   - Both rename it: the rename that reaches the server last wins.
2. **Delete wins.**
   - An `update` on a row that has `deletedAt` set is `rejected` (`SYNC_ENTITY_DELETED`). The row stays deleted.
   - Deleting a board, column or card cascades to its children on the server: they get `deletedAt` and a new `seq`.
3. **Parent must be alive.** If a `create` or move targets a deleted (or missing) parent, the op is `rejected` (`SYNC_PARENT_DELETED`). Example: moving a card into a column someone else deleted. The client's next pull shows the card where the server has it. If its old column is also gone, the card is gone too.
4. **`create` of an existing id** from a member of the same workspace is applied as an `update`. This covers a crash between "server applied" and "client received the response" when the op somehow got a new `opId`. `opId` dedupe normally catches this first.
5. **Positions.**
   - Two devices may put cards between the same neighbours and get the same key. Sorting by `(position, id)` keeps the order deterministic, and the next move of either card gets a fresh key.
   - The server does not rebalance keys.
6. **Integrity checks:**
   - `card.boardId` must equal `column.boardId`.
   - `workspaceId` is derived from the parent and cannot be changed.
   - Entities cannot be moved across boards (MVP).
   - A violation is `rejected` (`SYNC_INVALID_OP`).
7. **Permissions.**
   - Any workspace member may edit boards and cards. Roles only matter for workspace administration (phase 2).
   - An op for a workspace the user does not belong to is `rejected` (`SYNC_FORBIDDEN`). It is not a 403 for the whole batch, so other ops still apply.

## 6. Applying pulled rows on the client (rebase)

For every pulled row, inside one Drift transaction per page:
1. **No pending outbox ops** for this entity: overwrite the local row with the server row.
2. **Pending ops exist** (local changes not yet pushed): write the server values **except** for the fields that pending ops change. The local intent is kept and will reach the server with the next push. This is the client-side mirror of field-level LWW.
3. **The server row is a tombstone:** delete locally (soft delete) and drop the pending ops for this entity and its children. Delete wins (§5).
4. **Unknown parent** (for example a card whose board has not arrived yet in this page): insert anyway. Foreign keys are satisfied because the pull orders entities parent-first within a page (boards, columns, cards, checklist items, comments). Rows whose parent is missing on the client are kept and become visible once the parent arrives.

**Losing access.** If pull returns 404 for a workspace (the user was removed), the client deletes that workspace's boards, cards, outbox ops and cursor, and the workspaces list refreshes.

Watch streams (phase 3) pick up these writes automatically, so open screens update in place.

## 7. Sync engine (client)

`lib/core/sync/sync_engine.dart` is a single instance in get_it. It is started after sign-in and stopped on sign-out.

The cycle is push, then pull, and never runs in parallel:
1. **Push.** While the outbox is not empty: send the oldest 100 ops and process the results.
2. **Pull.** For each cached workspace: loop pull pages until `hasMore == false`.

Triggers (all coalesced into "run one more cycle when the current one ends"):
- App start and sign-in.
- Local mutation (debounced 500 ms).
- Network becomes available (`connectivity_plus`).
- App resumed from background.
- Every 60 s while in the foreground.
- Socket.IO "board changed" event (phase 5).

Errors:
- **Network or 5xx:** exponential backoff of 1 s, 2 s, 4 s … capped at 5 min, with jitter. `attempts` is incremented for the ops that were sent.
- **401 that the auth interceptor cannot refresh:** the session ends (existing behaviour) and the engine stops.
- **4xx on the whole request** (for example a malformed batch, which would be a bug): the batch is logged and its ops are marked rejected so the queue never gets stuck.

Status for the UI (`SyncStatus`):

| Status | Meaning | Shown as |
|---|---|---|
| `synced` | Outbox empty, last cycle succeeded | Cloud with a check mark |
| `syncing` | Cycle in progress | Animated cloud |
| `pending(n)` | Offline, `n` ops waiting | Cloud-off icon with a badge `n` |
| `error` | Backoff after a server error | Cloud with an alert icon; tap retries now |

The indicator is in the board and boards app bars, with a semantic label for screen readers.

## 8. Sign-out and account switching

- Signing out keeps local data and the outbox (phase 3 behaviour). The same user signing in again simply continues syncing.
- If the outbox is not empty at sign-out, a dialog warns that **n changes are not synced yet** and offers "Sync and sign out" or "Sign out anyway".
- A **different** user signing in triggers `AppDatabase.claimFor`, which wipes everything including unsynced ops. The warning above is the user's last chance to keep them.

## 9. Server implementation outline

- Prisma models:
  - `Board`, `BoardColumn`, `Card`, `ChecklistItem` (and `Comment` in phase 5), each with `workspaceId`, `seq BigInt`, `version Int`, `deletedAt`.
  - Indexes on `(workspaceId, seq)` and on parent ids.
- `position` columns are created with `COLLATE "C"` in the migration SQL. Prisma has no attribute for it, so the migration is edited by hand.
- `SyncModule`:
  - `SyncController` exposes push and pull, with DTO validation per entity.
  - `SyncService` holds the transaction and advisory lock.
  - One `EntityHandler` per entity covers payload whitelist, parent checks and cascade.
- `sync_seq` is a Postgres sequence. `nextval` is called through `$queryRaw` inside the push transaction.
- After a push commits, the service emits `board.changed(boardIds)` internally. Phase 5 forwards that event to Socket.IO rooms.

## 10. Testing plan

Server (Vitest e2e on `flowboard_test`):
- push → pull round-trip for each entity; `since` cursor and `hasMore` paging.
- Same `opId` twice gives `duplicate`, with no double write.
- Two users updating different fields both survive; the same field gives the last write.
- Update after delete is rejected; move into a deleted column is rejected; cascade deletes produce tombstones in pull.
- A non-member's ops are rejected and their pull gets 404.
- Concurrent pushes into one workspace: pulled `seq` values have no gaps relative to commit order.

Client (flutter test):
- Every repository mutation writes exactly one row change plus the matching outbox op in the same transaction (rollback test).
- Rebase: a pulled row does not overwrite fields with pending local ops; a tombstone removes the row and its pending ops.
- Engine against a fake API:
  - the outbox drains;
  - backoff on network errors;
  - rejected ops are dropped;
  - status transitions.
- Convergence: two `AppDatabase` instances ("Alice" and "Bob") with an in-memory fake server implementing §5 make conflicting edits offline, sync, and end with identical board content.

Manual acceptance:
1. Airplane mode on.
2. Create a board, add five cards and move two.
3. Kill the app, reopen it, and check that everything is there with the indicator showing `pending`.
4. Network on: the indicator goes to `synced`.
5. A second client (a second emulator, or the PowerShell script in the README) sees the same board.

## 11. Open questions for review

1. **Row `seq` instead of an append-only `change_log`** (§2): is a compacted log acceptable? It is simpler, and initial sync is free.
2. **Field-level LWW, delete wins** (§5): acceptable for the diploma scope?
3. **Workspaces stay online-only to create, join and leave** (§1): boards and cards work offline inside them.
4. **The sign-out warning when changes are unsynced** (§8): OK, or should sign-out be blocked until sync finishes?
