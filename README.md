# FlowBoard

Mobile-first, offline-first Kanban for small teams. Flutter (Android/iOS) + NestJS + PostgreSQL + Redis.
Interface languages: Kazakh, Russian, English.

```
apps/mobile   Flutter app
apps/api      NestJS backend
docs/         architecture, ADRs, backlog
```

## Requirements
- Windows 10/11 with PowerShell
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- Node.js 24 LTS
- Flutter stable (3.44+) and Android Studio with an Android SDK and an emulator (AVD)

Check the toolchain:
```powershell
flutter doctor
node --version
docker --version
```

## 1. Start Postgres and Redis
```powershell
docker compose up -d
docker compose ps        # both services should be "healthy"
```
Defaults are in `.env.example`; copy it to `.env` to change ports or credentials. A second database, `flowboard_test`, is created for e2e tests.

## 2. Run the API
```powershell
cd apps/api
Copy-Item .env.example .env
# Put a real secret into JWT_ACCESS_SECRET:
node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"
npm install            # also generates the Prisma client
npm run db:deploy      # applies migrations to the dev database
npm run start:dev
```
- Health (checks Postgres and Redis): `Invoke-RestMethod http://localhost:3000/health`
- Swagger UI: http://localhost:3000/docs

Checks (e2e tests use the `flowboard_test` database and apply migrations themselves; Docker must be running):
```powershell
npm run lint; npm run format:check; npm run typecheck; npm test; npm run test:e2e
```
After changing `prisma/schema.prisma`: `npm run db:migrate -- --name <change>`.

### Try two users in one workspace (PowerShell)
```powershell
$api = 'http://localhost:3000'
$a = Invoke-RestMethod "$api/auth/register" -Method Post -ContentType 'application/json' -Body '{"email":"alice@example.com","password":"password123","name":"Alice"}'
$b = Invoke-RestMethod "$api/auth/register" -Method Post -ContentType 'application/json' -Body '{"email":"bob@example.com","password":"password123","name":"Bob"}'
$ha = @{ Authorization = "Bearer $($a.tokens.accessToken)" }
$hb = @{ Authorization = "Bearer $($b.tokens.accessToken)" }
$ws = Invoke-RestMethod "$api/workspaces" -Method Post -Headers $ha -ContentType 'application/json' -Body '{"name":"Team"}'
$inv = Invoke-RestMethod "$api/workspaces/$($ws.id)/invites" -Method Post -Headers $ha
Invoke-RestMethod "$api/invites/$($inv.token)/accept" -Method Post -Headers $hb
Invoke-RestMethod "$api/workspaces/$($ws.id)/members" -Headers $ha | ConvertTo-Json -Depth 4
```

## 3. Run the mobile app
Start an Android emulator (Android Studio → Device Manager, or `flutter emulators --launch <id>`), then:
```powershell
cd apps/mobile
flutter pub get
flutter run --dart-define-from-file=config/dev.json
```
`config/dev.json` points the app at `http://10.0.2.2:3000` — the emulator's alias for your PC.
Override for other targets, e.g. a physical device on the same Wi-Fi:
```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000
```

Invite links have the form `flowboard://app/invite/<token>`. To open one on the emulator:
```powershell
adb shell am start -a android.intent.action.VIEW -d "flowboard://app/invite/<token>"
```

Checks:
```powershell
flutter gen-l10n; dart format --set-exit-if-changed lib test; flutter analyze; flutter test
```
After changing `@freezed` / `@JsonSerializable` models regenerate code:
```powershell
dart run build_runner build --delete-conflicting-outputs
```
(If `dart` on your PATH is not Flutter's own, call it explicitly, e.g. `& "$((Get-Command flutter).Source | Split-Path)\dart.bat" run build_runner build`.)

## Offline sync: manual check
Design: [docs/sync.md](docs/sync.md). The cloud icon in the board's app bar shows the state (synced / syncing / `n` changes waiting / error); tap it to sync now.
1. Turn on airplane mode on the emulator.
2. Create a board, add a few cards and move two of them. The icon shows the number of queued changes.
3. Kill the app (swipe it away), start it again: everything is still there.
4. Turn the network back on: within a couple of seconds the icon turns into a check mark.
5. Sign in as a second user of the same workspace (another emulator, or `flutter run -d <device>` on a second device) and open the board: it has the same columns and cards.

Inspect what the server has (PowerShell, after logging in as in the snippet above):
```powershell
Invoke-RestMethod "$api/sync/pull?workspaceId=$($ws.id)&since=0" -Headers $ha | ConvertTo-Json -Depth 5
```

## iOS
iOS cannot be built on Windows. The code avoids Android-only APIs; iOS builds will run on a macOS CI runner (phase 7). On the iOS simulator use `API_BASE_URL=http://localhost:3000`.

## Troubleshooting
- **`flutter pub get` fails with a symlink error** — enable Windows Developer Mode: `start ms-settings:developers`.
- **Emulator cannot reach the API** — the API listens on `0.0.0.0:3000`; allow Node.js through Windows Firewall for private networks.
