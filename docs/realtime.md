# Real-time updates and comments

Status: implemented in phase 5. Data still travels only through `/sync/push` and `/sync/pull` ([sync.md](sync.md)). The socket only tells a client **when** to pull.

## 1. Why "notify, then pull"
- One code path for data: the pull already handles cursors, tombstones, rebase over pending local edits and membership checks. A patch sent over the socket would need all of that a second time.
- An event is lost when the socket drops, but the change is not. On every (re)connect the client pulls anyway, so a missed event costs at most one cycle of delay.
- Events carry ids only, so nothing leaks to a socket that is still in a room it should have left.

## 2. Connection (server: `apps/api/src/realtime`)
- Socket.IO on the API's HTTP port, default path `/socket.io`. The mobile client uses the WebSocket transport only.
- **Handshake:** `auth: { token: <access JWT> }`. The gateway verifies it with the same secret as REST. A missing, invalid or expired token is refused with `connect_error` and message `UNAUTHORIZED`.
- **Token expiry:** the server disconnects the socket when its access token expires (`disconnect` reason `io server disconnect`). The client reconnects with a fresh token, so a socket never outlives the token it was opened with.
- **Rooms:**
  - Every socket joins `user:<userId>`, which is used for revocation.
  - The client joins `board:<boardId>` for each board on screen.
- **Several API instances:** the Redis adapter (`@socket.io/redis-adapter`) shares rooms and broadcasts between instances.
- The global HTTP guards (JWT, throttling) skip socket messages. Authentication happens once, in the handshake.

### Client → server (with acknowledgement)

| Event | Payload | Ack |
|---|---|---|
| `board:join` | `{ boardId }` | `{ ok: true }` or `{ ok: false, code }` |
| `board:leave` | `{ boardId }` | `{ ok: true }` |

Join error codes:
- `NOT_FOUND`: the board does not exist, is deleted, or the user is not a member of its workspace. Like REST, the two cases are not distinguished.
- `INVALID`: the payload is not a UUID.
- `TOO_MANY_ROOMS`: more than 50 board rooms per socket.

### Server → client

| Event | Payload | Sent when |
|---|---|---|
| `board:changed` | `{ boardId }` | A `/sync/push` applied at least one op to the board: the board itself, a column, card, checklist item or comment. One event per board per push. |
| `workspace:removed` | `{ workspaceId }` | The user left or was removed. Their sockets are also taken out of that workspace's board rooms. |

The device that pushed also gets `board:changed` and does one extra, empty pull. That is cheaper than tracking socket ids per request.

## 3. Client (`apps/mobile/lib/core/sync`)
- `RealtimeClient` (logic) runs on top of `RealtimeTransport`. The app uses `SocketIoTransport` (`socket_io_client`); tests use a fake.
- It runs while the user is signed in, alongside the `SyncEngine` (`injector.dart`).
- **Rooms follow the screen.** `BoardsRepository.watchBoard` joins `board:<id>` while its stream has listeners and leaves when the last listener cancels. The card screen is nested under the board route, so the room stays joined there too.
- **Triggers.** All of these feed `RealtimeClient.changes`, which is one of the `SyncEngine` triggers (cycles are coalesced, docs/sync.md §7):
  - a server event;
  - a successful (re)connect, to catch up on missed events;
  - a successful join, so a board is fresh when opened.
- **Tokens.** Every handshake asks `AccessTokenSource` for a token. It refreshes the token (through the auth interceptor's single-flight refresh) when the token expires within a minute.
  - A refused handshake forces a refresh and retries right away, then backs off from 1 s up to 1 min.
  - A network drop is retried by the socket itself.
- **Boards created offline.** A join can fail with `NOT_FOUND` because the board has not been pushed yet. Such joins are retried after every successful sync cycle.

Latency budget for "a card moved on one device appears on the other":
- 500 ms push debounce (docs/sync.md §7);
- one push round trip;
- the event;
- one pull round trip.

Measured against a local API: about 540 ms (`test/live/realtime_live_test.dart`, see README).

## 4. Comments and @mentions
- `comment` is a synced entity like the others ([sync.md](sync.md) §2):
  - only the author may edit or delete a comment;
  - deleting a card deletes its comments.
- **Format.** The text keeps a readable `@Name`, and `mentions` holds the ids of the members it names. The text stays meaningful without the member list, for example in push notifications (phase 6).
- **Client rules** (`features/comments/domain/mentions.dart`):
  - typing `@` suggests workspace members by any word of their name or by e-mail;
  - picking one inserts `@Full Name `;
  - on save, `mentions` is computed from the text: an exact `@Name` that stands alone; the longest name wins, so `@Anna Lee` is not also `@Anna`;
  - editing recomputes `mentions`. Without a member list (offline, nothing cached) an edit keeps the old ones.
- **Server rule:** ids that are not members of the workspace are dropped, not rejected. A comment written offline survives a mentioned teammate leaving, and phase 6 cannot notify outsiders.
- Comments not yet acknowledged by the server (`version == 0`) show a clock icon.
