# Push notifications

Status: implemented in phase 6. **Firebase is optional.** Without it, the API and the app run normally and simply send and receive no pushes. Section 4 explains how to turn push on.

## 1. What is sent

| Type | When | Who gets it | Example (ru) |
|---|---|---|---|
| `assigned` | A card gets a new assignee (on create or on change) | The assignee, unless they assigned themselves | **Вам назначена задача** — «Intro» на доске «Diploma» · от Aigerim |
| `mentioned` | A comment mentions someone; when a comment is edited, only people newly mentioned | Mentioned members except the author | **Вас упомянули** — Aigerim в «Intro»: @Timur check the survey |
| `dueTomorrow` | The day before the due date, between about 09:00 and 22:00 local time | The assignee, once per card and due date | **Срок — завтра** — «Intro» на доске «Diploma» |

Rules:
- Only current members of the card's workspace are notified. `assigneeId` has no foreign key, so this check matters.
- A card in the **last column** of a board that has two or more columns counts as done and gets no reminder. In every template the last column is "Done".
- Texts are rendered on the server in the device's language (`kk`, `ru` or `en`) from `apps/api/src/notifications/messages.ts`. The Russian texts avoid past-tense verbs, which would need the actor's gender.

**Why "the day before, 09:00–22:00" needs no time zone.** The app stores a due date as the local midnight that starts the due day (`T`). The server reminds when `T − 15 h < now ≤ T − 2 h`, which is 09:00–22:00 local time on the previous day in any time zone. The job runs every 15 minutes.

## 2. How it works

```
Sync push ──► SyncService.activity ──► NotificationsService ──► PushSender ──► FCM ──► device
                                         ▲     (FcmPushSender / NoopPushSender)
           every 15 min: sendDueReminders┘
```

### Server (`apps/api/src/notifications`)
- **Device tokens.**
  - `PUT /devices { token, platform: android|ios, locale: en|ru|kk }` registers or refreshes a token. If another account had the same token, it moves to the caller (the device switched accounts).
  - `DELETE /devices/:token` removes it. Only the caller's own token is removed.
  - Tokens that FCM reports as unregistered are deleted after each send.
- **Activity.** Sync handlers report `assigned` / `mentioned` for each applied op. The events are published only after the op's transaction commits, so a rejected or duplicate op never notifies anyone.
- **Due reminders.** Each `(card, due date)` pair is first claimed in `due_reminders` (insert-or-skip), then sent. Several API instances never send the same reminder twice. A new due date gets a new reminder.
- **Sender.**
  - `PushSender` is the abstraction.
  - `FcmPushSender` uses `firebase-admin`, which is loaded only when configured.
  - `NoopPushSender` is used when `FIREBASE_SERVICE_ACCOUNT_FILE` is empty, or when the file cannot be read. The error is logged and the API keeps running.
- Notifications are best effort: a failure is logged and never fails the sync request.

### App (`apps/mobile/lib/core/notifications`)
- **The abstraction** is `NotificationService`.
  - `PushNotificationService` wraps the Firebase SDK through `PushPlatform`.
  - `NoopNotificationService` is used when the build has no `PUSH_ENABLED=true`, or when `Firebase.initializeApp()` fails.
- **After sign-in:** the app asks for permission (Android 13+, iOS) and registers the token with the current UI language. It registers again when the language changes, when the token is refreshed, and after a failed attempt once a sync succeeds (back online).
- **Before sign-out:** the token is unregistered while the session is still valid, then deleted on the device. The next account gets a fresh token.
- **Tapping a notification** opens the card. A tap that launches the app is kept until the UI is ready.
- **Pushes that arrive while the app is open** show a snackbar with an "Open" action and start a sync. On iOS the system banner is turned off in the foreground, so both platforms behave the same.

### Payload
`data` (all strings), used by the app to open the card:
```json
{ "type": "assigned | mentioned | dueTomorrow", "workspaceId": "…", "boardId": "…", "cardId": "…" }
```
Messages are FCM *notification* messages: the system shows them when the app is in the background or killed. The app needs no background isolate.

## 3. Running without Firebase (default)
Nothing to do:
- The API logs `Push notifications are off: FIREBASE_SERVICE_ACCOUNT_FILE is not set`.
- The app is built without `PUSH_ENABLED`, so it never touches Firebase.
- Android builds without `google-services.json`: the Gradle plugin is applied only when the file exists.
- The client config files and the service account key are listed in `.gitignore`.

## 4. Setting up Firebase, step by step

### 4.1 Create the project
1. Open <https://console.firebase.google.com> → **Add project** → name it, for example `flowboard-dev`. Google Analytics is not needed.
2. In **Project settings → Cloud Messaging**, make sure **Firebase Cloud Messaging API (V1)** is enabled. It is enabled by default on new projects.

### 4.2 Android app
1. **Project settings → General → Your apps → Add app → Android.**
2. Android package name: `kz.flowboard.flowboard`. The other fields are optional.
3. Download `google-services.json` and put it at `apps/mobile/android/app/google-services.json`. It is git-ignored.
4. Nothing else is needed: the `com.google.gms.google-services` plugin is already declared and turns itself on when the file exists.

### 4.3 iOS app (needs a Mac and an Apple Developer account)
1. **Add app → iOS** with bundle ID `kz.flowboard.flowboard`. Download `GoogleService-Info.plist`.
2. In Xcode, open `apps/mobile/ios/Runner.xcworkspace` and drag the plist into **Runner**. Check *Copy items if needed* and target *Runner*.
3. Under **Runner → Signing & Capabilities**:
   - add **Push Notifications**;
   - add **Background Modes** with *Remote notifications* checked.
4. Apple Developer → **Keys** → create a key with **Apple Push Notifications service (APNs)** and download the `.p8` file.
5. In Firebase, go to **Project settings → Cloud Messaging → Apple app configuration** and upload the `.p8` with its Key ID and your Team ID.
6. The iOS Simulator receives pushes only with Xcode 14+ on an Apple silicon Mac. Use a real device if in doubt.

### 4.4 Server key
1. **Project settings → Service accounts → Generate new private key**. This downloads a JSON file. **It is a secret.**
2. Save it outside git, for example `apps/api/secrets/firebase-service-account.json` (the folder is git-ignored).
3. In `apps/api/.env`:
   ```
   FIREBASE_SERVICE_ACCOUNT_FILE=secrets/firebase-service-account.json
   ```
   A relative path is resolved from `apps/api`, where the API is started.
4. Restart the API. The log line "Push notifications are off" must be gone.

### 4.5 Run the app with push
```powershell
cd apps/mobile
flutter run --dart-define-from-file=config/dev.json --dart-define=PUSH_ENABLED=true
```
Use an emulator image **with Google Play** (Device Manager shows the Play Store icon), or a physical device. Images without Google Play services cannot receive FCM messages. Allow notifications when the app asks.

### 4.6 Check
1. Two users of one workspace sign in on two devices (README, "Try two users in one workspace"). Send the app on the second device to the background.
2. On the first device, open a card and pick the second user as the assignee → a notification "Вам назначена задача / You have a new task" appears on the second device. Tap it: the card opens.
3. Write a comment that mentions the second user with `@` → a "mentioned" notification.
4. Set a card's due date to tomorrow (assignee = the second user, not in the last column) → within 15 minutes, between 09:00 and 22:00, a "due tomorrow" notification.
5. With the app open, the same events show as a snackbar with "Open".

## 5. Troubleshooting
| Symptom | Cause / fix |
|---|---|
| App log `push: Firebase is not configured` | `google-services.json` / `GoogleService-Info.plist` is missing or for another package name. |
| No permission prompt | Android below 13 needs no prompt; on Android 13+ a prompt that was dismissed twice is not shown again. Enable notifications in system settings. |
| Token registered, nothing arrives | Emulator without Google Play; or the API was started without `FIREBASE_SERVICE_ACCOUNT_FILE` (check the log). |
| API log `Could not load the Firebase service account` | Wrong path or a broken JSON file; push stays off and the API keeps running. |
| Pushes in the wrong language | The language is sent with the token; open the app once after changing it so the token is registered again. |
