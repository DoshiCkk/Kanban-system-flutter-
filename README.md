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
npm install
npm run start:dev
```
- Health: `Invoke-RestMethod http://localhost:3000/health`
- Swagger UI: http://localhost:3000/docs

Checks:
```powershell
npm run lint; npm run format:check; npm run typecheck; npm test; npm run test:e2e
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

Checks:
```powershell
flutter gen-l10n; dart format --set-exit-if-changed lib test; flutter analyze; flutter test
```

## iOS
iOS cannot be built on Windows. The code avoids Android-only APIs; iOS builds will run on a macOS CI runner (phase 7). On the iOS simulator use `API_BASE_URL=http://localhost:3000`.

## Troubleshooting
- **`flutter pub get` fails with a symlink error** — enable Windows Developer Mode: `start ms-settings:developers`.
- **Emulator cannot reach the API** — the API listens on `0.0.0.0:3000`; allow Node.js through Windows Firewall for private networks.
