# Fantasy League 7 — Android app

A native Flutter client for the existing `fantacy-leauge` platform. It talks to
the same Express + Prisma backend and the same Postgres database as the React
web app — no backend changes were needed, because the API already authenticates
with `Authorization: Bearer <jwt>` and `backend/server.js` explicitly allows
requests with no `Origin` header.

All three roles are supported: **Member**, **Manager** and **Admin**.

## Running against the local backend

1. Start the API (from the repo root):

   ```bash
   cd backend && npm run dev
   ```

   It listens on port **5001** (`PORT` in `backend/.env` overrides this).

2. Start an Android emulator, then:

   ```bash
   cd mobile && flutter run
   ```

The app defaults to `http://10.0.2.2:5001` — the emulator's alias for the host
machine's `localhost`.

### Pointing at a different backend

The base URL is a compile-time constant, overridable per run:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.5:5001
```

Physical device on the same Wi-Fi? Use the host's LAN IP as above **and** add
that IP to `android/app/src/main/res/xml/network_security_config.xml`, or
Android will block the plain-HTTP request.

Alternatively, forward the port over USB and keep the default host:

```bash
adb reverse tcp:5001 tcp:5001
```

## Building an APK

```bash
cd mobile && flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk` (~52 MB).

For a smaller download, split per architecture:

```bash
flutter build apk --release --split-per-abi
```

Install on a connected device or running emulator:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## Before shipping to production

The current build is configured for local development. Three things must change:

1. **Point at the HTTPS API** — build with
   `--dart-define=API_BASE_URL=https://fantacyleauge.com`.
2. **Remove the cleartext exemption** — delete
   `android/app/src/main/res/xml/network_security_config.xml` and the
   `android:networkSecurityConfig` attribute in `AndroidManifest.xml`, so the
   app refuses plain HTTP entirely.
3. **Sign the release** — the APK is currently signed with the debug key
   (`android/app/build.gradle.kts` still uses `signingConfigs.debug`). Create an
   upload keystore and wire it up before publishing.

## Layout

```
lib/
  config/       api_config.dart (base URL), theme.dart
  models/       Prisma-shaped models + json_utils.dart
  services/     one class per API area, all sharing ApiClient
  state/        AuthState (session, role, credits)
  screens/
    auth/         login, register
    member/       dashboard, match groups, place bet, view bets,
                  my bets, wallet, referral
    management/   matches, match form, manage match, group form,
                  squads, result form, members
                  (shared by Manager and Admin)
    admin/        dashboard, club form
    shared/       account menu, change password
  widgets/      common.dart (AsyncView, StatusChip, formatters, …)
```

Managers and admins drive the same management screens; admin-only calls pass a
`clubId`, which selects the `.../:clubId` endpoint variants. That avoids a
duplicate set of screens for the two roles.

## Domain notes

- A **combination** is three symbols from `[1-7A-G]`, compared
  order-insensitively (the backend sorts the characters). `1` – `7` are team 1's
  seven scoring slots, `A` – `G` are team 2's.
- **First Better** groups let one member claim each combination; **Multi Better**
  lets many members hold the same one but each member only once; **Bidding
  Method** additionally requires a `minimumIncrement`.
- A result is **exactly seven non-negative integers per team**
  (`backend/utils/resultPolicy.js`), and must be saved before *Approve credits*
  will settle the match.
- Members can only see matches once an admin has assigned them to a club.

## Tests

```bash
cd mobile && flutter test
```

Covers the JSON parsing quirks that come from the backend's mixed `id`/`_id`
aliasing, role parsing, and the combination canonicalisation rule that must stay
in step with `placeBet`.

## Known local-build note

`android/gradle.properties` sets `kotlin.incremental=false`. Kotlin's
incremental compiler corrupts its own caches on this Windows setup, failing
`:shared_preferences_android:compileReleaseKotlin` with "Could not close
incremental caches" — and a `flutter clean` does not clear it. Plugin sources
never change, so the extra compile time is negligible.
