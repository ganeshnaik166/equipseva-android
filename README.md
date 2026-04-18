# EquipSeva Android

Native Kotlin + Jetpack Compose app for the EquipSeva ecosystem (medical-equipment marketplace + repair services for Indian hospitals).

This is the **Phase 0 foundations scaffold**: Hilt, Supabase Kotlin SDK, Room, DataStore, FCM, Sentry, Crashlytics, WorkManager — all wired but no real screens yet. Phase 1 (buyer MVP: parts browse + cart + Razorpay + orders + push) lands next.

## Stack

| Layer | Choice |
|---|---|
| Language | Kotlin 2.1 (no Java) |
| UI | Jetpack Compose + Material 3 |
| Min / target / compile SDK | 26 / 35 / 35 |
| Build | Gradle 8.11 KTS + version catalog |
| DI | Hilt + KSP |
| Networking | Retrofit + OkHttp + kotlinx.serialization (non-Supabase REST) |
| Auth/data | `io.github.jan-tennert.supabase` (auth, postgrest, realtime, storage) |
| Local DB | Room (KSP) |
| Prefs | DataStore Preferences |
| Background | WorkManager |
| Push | Firebase Messaging |
| Crash/perf | Firebase Crashlytics + Sentry Android |

Bundle id: `com.equipseva.app` (release) / `com.equipseva.app.debug` (debug).

## First-time setup

1. **Install Android Studio Iguana (2023.2.1)+** with JDK 17.
2. **Clone** the repo into your Android Studio workspace.
3. **Copy env file**:
   ```bash
   cp local.properties.example local.properties
   ```
   Fill in `SUPABASE_URL` and `SUPABASE_ANON_KEY` (the rest can stay blank for Phase 0).
4. **Add `google-services.json`** at `app/google-services.json` — download it from Firebase Console for the EquipSeva project. The committed `.example` file is just a template. FCM and Crashlytics will not initialize without the real file.
5. **Open the project in Android Studio** → Sync Gradle. The Gradle wrapper jar will be downloaded automatically; if you ever need to regenerate it manually run `gradle wrapper --gradle-version 8.11.1` from a system Gradle install.
6. **Build & run** — `Run → app` on an emulator or device (API 26+).

## What's wired

- Single-activity Compose host with bottom-nav (Home, Parts, Repair, Orders, Profile).
- Supabase client provided as a singleton (`core/supabase/SupabaseModule.kt`) — Auth, Postgrest, Realtime, Storage.
- `AuthRepository` exposing email + password, email OTP, Google ID-token, sign-out. **Phone OTP is intentionally absent** (locked decision).
- Room database with entities: Cart, Order, RepairJob, Message, Outbox, DeviceToken.
- DataStore prefs (active role, theme, onboarding flag).
- FCM service registers four notification channels (`orders`, `jobs`, `chat`, `account`) matching the cross-surface push payload contract.
- `DeviceTokenRegistrar` upserts the FCM token to Supabase `device_tokens` keyed by `user_id` + `platform`.
- `OutboxWorker` skeleton — Phase 3 wires per-kind dispatch + retry policy.
- `SentryInitializer` + `CrashReporter` (single API for non-fatal exceptions reported to both Crashlytics and Sentry).
- Adaptive launcher icon + splash screen on brand green `#0B6E4F`.
- Deep link intent filters for Razorpay return (`https://equipseva.com/pay/return`) and Supabase auth callback (`equipseva://auth-callback`) — handlers land in Phase 1.

## What's intentionally NOT here

- **Razorpay SDK + checkout flow** — Phase 1.
- **Real screens** beyond placeholders — Phase 1/2.
- **Maps SDK** — Phase 2.
- **Outbox dispatch logic** — Phase 3 (only the worker class scaffold exists).
- **KYC camera flow** — Phase 2.
- **Release signing config** — Play Console access still pending; debug-only for now.
- **CI workflow** (`.github/workflows/android.yml`) — separate task.
- **Hindi `values-hi/` strings** — locked decision: English-only at launch.

## Module layout

```
app/src/main/kotlin/com/equipseva/app/
├── EquipSevaApplication.kt
├── MainActivity.kt
├── navigation/                       # AppNavGraph, Routes
├── core/
│   ├── auth/                         # AuthRepository (interface + Supabase impl) + Hilt module
│   ├── data/                         # Room: AppDatabase, entities/, dao/, prefs/UserPrefs
│   ├── network/                      # OkHttp + Retrofit + kotlinx.serialization
│   ├── supabase/                     # Hilt-provided SupabaseClient
│   ├── push/                         # FCM service, channels, device-token registrar
│   ├── storage/                      # Supabase Storage wrapper (signed URLs only)
│   ├── sync/                         # OutboxWorker + scheduler
│   ├── observability/                # Sentry init + CrashReporter
│   └── util/                         # BuildConfig accessors
├── designsystem/                     # Theme, Color, Typography, Spacing, components/
└── features/                         # Placeholder screens (home, auth, marketplace, orders, repair, profile)
```

**Rule:** `features/*` may depend on `core/*` and `designsystem/*` but **never on each other**. Cross-feature flows go through the nav graph.

## Cross-surface contracts (must match web + iOS)

1. Supabase schema + RLS (web/iOS read this from `supabase/migrations/` in the monorepo).
2. REST/edge endpoint payload shapes.
3. Brand green `#0B6E4F` (defined in `designsystem/theme/Color.kt` — single source on Android).
4. Push payload JSON: `{ "channel": "orders|jobs|chat|account", "title": "...", "body": "...", ... }` — must match FCM and APNs.
5. Parity matrix (lives in `PRD-mobile.md`).

## Verification checklist

- `./gradlew :app:assembleDebug` produces an APK at `app/build/outputs/apk/debug/`.
- App installs as `com.equipseva.app.debug` and launches to the Home placeholder.
- All four notification channels visible under Settings → Apps → EquipSeva → Notifications.
- `./gradlew :app:test` passes the placeholder unit test.

## Blockers

- **Play Console access** — pending. Release signing + upload workflow held until access lands.
- **Real `google-services.json`** — required before FCM/Crashlytics can initialize.
- **Supabase env** — without `SUPABASE_URL` + `SUPABASE_ANON_KEY` in `local.properties`, app launches but no auth/data calls work.

## Next phase (Phase 1 — Buyer MVP)

Per `PRD-mobile.md` parity matrix and Master PRD §4: parts browse, cart, Razorpay native checkout, orders tracking, push notifications wired end-to-end. Gate: hospital buyer completes a purchase on a real device.
