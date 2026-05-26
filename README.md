# EquipSeva Android

Native Kotlin + Jetpack Compose app for the EquipSeva ecosystem — a healthcare-equipment service platform for Indian hospitals: repair-job marketplace, engineer rotation, and annual maintenance contracts (AMC) with escrow.

The marketplace / parts-cart leg that lived in early Phase 1 has been retired — v1 ships as a service-only product (repair + AMC + payouts). Hospitals book repair jobs and AMC contracts; engineers bid on jobs and complete scheduled visits; founder ops resolves disputes, KYC, and integrity events.

## Stack

| Layer | Choice |
|---|---|
| Language | Kotlin 2.x |
| UI | Jetpack Compose + Material 3 |
| Min / target / compile SDK | 26 / 35 / 36 |
| Build | Gradle KTS + version catalog |
| DI | Hilt + KSP |
| Networking | Ktor (via supabase-kt) + OkHttp engine |
| Auth/data | `io.github.jan-tennert.supabase` (auth, postgrest, realtime, storage) |
| Local DB | Room (KSP) |
| Prefs | DataStore Preferences |
| Background | WorkManager |
| Push | Firebase Cloud Messaging |
| Maps | Google Maps Compose 6.x |
| Payments | Razorpay Standard Checkout (AMC subscriptions + repair-job escrow) |
| Crash/perf | Firebase Crashlytics + Sentry Android |
| Credentials | androidx.credentials + Google ID Token (Sign in with Google) |

Bundle id: `com.equipseva.app` (release) / `com.equipseva.app.debug` (debug).

## First-time setup

1. **Install Android Studio Iguana (2023.2.1)+** with JDK 17.
2. **Clone** the repo.
3. **Copy env file**:

   ```bash
   cp local.properties.example local.properties
   ```

   Fill in `SUPABASE_URL` and `SUPABASE_ANON_KEY` at minimum. `MAPS_API_KEY` is required for the repair-feed + job-detail maps; `RAZORPAY_KEY`, `GOOGLE_WEB_CLIENT_ID`, `SENTRY_DSN` are optional in dev.
4. **Add `google-services.json`** at `app/google-services.json`. The committed `.example` template is enough to compile; FCM + Crashlytics need the real file from Firebase Console.
5. **Open in Android Studio** → Sync Gradle.
6. **Build & run** — emulator or device (API 26+).

## What's wired (v1)

### User-facing

- Single-activity Compose host with role-aware bottom nav (Hospital / Engineer / Founder).
- Auth: email + password, sign in with Google (Credential Manager + GoogleId provider), phone OTP add-on for KYC contact.
- Hospital flows: request service (5-step wizard with map picker + scheduled slot), my active jobs (filter-aware empty state), AMC contracts (create wizard + pause/cancel + visits), disputes, profile + KYC.
- Engineer flows: directory + public profile, my bids, active work (4-state), AMC visits, earnings, disputes, location-share.
- Founder ops: dashboard, KYC review queue (engineer + buyer), reports queue, escrow dispute resolution, AMC escalation detail, paused/expiring AMC, inactive engineers, integrity flags, cash-survey response history, spot-audit feedback, payments timeline, users search, categories.
- Chat: 1:1 + job-tied conversations with typing indicators, attachments, unread badges, optimistic send with outbox replay.
- Notifications: server-pushed FCM with per-category mute matrix, quiet-hours window, deep-link routing.

### Architecture / platform

- Supabase client provided as a singleton (`core/supabase/SupabaseModule.kt`) — Auth, Postgrest, Realtime, Storage.
- Room database for offline cache + outbox queue.
- DataStore prefs (active role, mute matrix, quiet hours, notification settings).
- FCM service registers three notification channels (`jobs`, `chat`, `account`) — legacy `orders` channel auto-deleted on upgrade.
- Outbox / Retry: four kinds (`CHAT_MESSAGE`, `PHOTO_UPLOAD`, `REPAIR_BID`, `JOB_STATUS`) with per-kind handlers, shared-device cross-user gates, classified-error retry vs poison-drop, MAX_ATTEMPTS = 5.
- Deep links: HTTPS App Links on `equipseva.com` with `autoVerify=true` — restricted path filters (`/job/`, `/chat/`, `/engineer/`, `/engineers`, `/notifications`) so legal / password-reset pages don't get captured.
- Network security: TLS-pinned release config in `src/main/res/xml`; debug variant in `src/debug/res/xml` allows user CAs via `<debug-overrides>` for Charles / Proxyman inspection (defense-in-depth: release builds can't ship user-CA trust).
- Sentry + Crashlytics, both routed through a single `CrashReporter` API. Sentry auto-init is off until a real DSN lands.

## Testing posture

`./gradlew :app:testDebugUnitTest` runs the pure-JUnit / Robolectric suite — **2,470+ `@Test` methods across 295 test files**, covering every `internal fun` helper in `app/src/main` plus the outbox handler integration paths.

The codebase follows a **helper-extraction + behaviour-pinning** strategy: any non-trivial gate / formatter / classifier is lifted out of its Compose / ViewModel / Repository scaffold into an `internal fun` and pinned by tests that include regression targets (server CHECK mirrors, glyph codepoints, locale stability, Unicode middle-dot / em-dash / arrow positions, role-aware copy, Trust-and-Safety cross-user gates).

Critical pinned T&S targets include:

- Outbox handler cross-user gates — four handlers with explicit LENIENT (chat / notification mark-read / repair-bid lenient-on-null) vs STRICT (job-status, refuse-on-null-actor) policy; pinned individually so a refactor that unified them would silently break either legacy-row drain or shared-device safety.
- Hospital can't self-report own job; password re-auth gates on delete-account / change-email; counterpart-blocked chat-send gate.
- Server CHECK mirrors: 1..5 rating, > 0.0 strict on bid amount + SLA hours + AMC fee, 4000-char chat message cap, 1cr bid amount upper cap.
- Locale stability: Turkish-locale i-casing on avatar initials + date-slot labels; Hindi/German comma-decimal on price + rating + coordinate formatters.

## CI

- `.github/workflows/android.yml` runs on every PR + push to main: `testDebugUnitTest` → `lintDebug` → `assembleDebug` → `assembleRelease` (R8 validation). Lint HTML report uploaded on failure.
- `.github/workflows/release-aab.yml` runs on `v*` tag push: re-runs tests + lint as defense-in-depth before producing the signed AAB and attaching to a GitHub Release.
- `.github/workflows/secret-scan.yml` runs gitleaks on every PR.
- `.github/workflows/check-assetlinks.yml` validates the App Links `assetlinks.json` host.
- Cron workflows: hourly + daily ticks against the Supabase keepalive endpoint.
- `.github/dependabot.yml` opens grouped weekly minor/patch PRs for Gradle deps + GitHub Actions; majors held back for coordinated toolchain upgrades.

## Module layout

```text
app/src/main/kotlin/com/equipseva/app/
├── EquipSevaApplication.kt
├── MainActivity.kt
├── navigation/                         # MainNavGraph, DeepLinkRouter, NotificationDeepLink, Routes
├── core/
│   ├── auth/                           # AuthRepository (Supabase impl), error classifier
│   ├── data/                           # Domain repos: chat, repair, profile, amc, engineers,
│   │                                   #   notifications, addresses, cashsurvey, spotaudit, etc.
│   ├── network/                        # Json / OkHttp / DataError → user-message funnel
│   ├── supabase/                       # Hilt-provided SupabaseClient
│   ├── push/                           # FCM service, notification channels, helpers
│   ├── storage/                        # Supabase Storage wrapper (signed URLs only)
│   ├── sync/                           # OutboxWorker + error classifier + handler interface
│   ├── observability/                  # Sentry init + CrashReporter
│   ├── payments/                       # Razorpay reconcilers (AMC + escrow)
│   ├── security/                       # Signature verifier
│   ├── location/                       # Saved service-location formatter
│   └── util/                           # Validators, file helpers, BuildConfig accessors
├── designsystem/                       # Theme, Color, Typography, EsRadius, components/
└── features/
    ├── about/                          # AboutScreen
    ├── activework/                     # ActiveWorkScreen (engineer 4-state)
    ├── amc/                            # AmcDetailScreen, CreateAmcWizard, MaintenanceContracts,
    │                                   #   AmcPaymentSheet, AmcVisitsScreen
    ├── auth/                           # SignIn, SignUp, ForgotPassword, RoleSelect, Welcome
    ├── chat/                           # ChatScreen, ConversationsScreen, ChatViewModel
    ├── earnings/                       # EngineerEarnings, EngineerActiveEscrows
    ├── engineer/                       # EngineerMyDisputes, EngineerAmcVisits, EngineerLocation
    ├── engineerprofile/                # EngineerProfileScreen (public-facing public profile)
    ├── founder/                        # 20+ ops screens (KYC, disputes, integrity, audits, ...)
    ├── home/                           # HomeHubScreen + cash survey + spot-audit nudges
    ├── hospital/                       # HospitalActiveJobs, HospitalDisputes, RequestService
    ├── kyc/                            # KycScreen + ViewModel + Aadhaar/PAN/cert sanitisation
    ├── mybids/                         # MyBidsScreen (engineer side)
    ├── notifications/                  # Inbox + per-category mute matrix + quiet-hours
    ├── onboarding/                     # TourScreen
    ├── profile/                        # ProfileScreen + role-edit + delete-account + export
    ├── repair/                         # RepairJobsScreen + Detail + bid composer + directory
    └── security/                       # ChangeEmail, ChangePassword
```

**Rule:** `features/*` may depend on `core/*` and `designsystem/*` but **never on each other**. Cross-feature flows go through the nav graph.

## Cross-surface contracts (must match web + iOS)

1. Supabase schema + RLS — read from `supabase/migrations/` in the monorepo.
2. REST / edge function payload shapes (e.g. `create-amc-payment-order`, `complete_repair_job`).
3. Brand green `#0B6E4F` (defined in `designsystem/theme/Color.kt` — single source on Android).
4. Push payload JSON: `{ "channel": "jobs|chat|account", "title": "...", "body": "...", "kind": "...", ...kind_specific }` — must match FCM and APNs.
5. Razorpay vocabulary: subscription statuses (Halted / Cancelled / Completed / Expired) match bank statement copy; payment-order status strings match the edge function `verify-amc-payment` response codes.
6. AMC expiry boundaries: 7-day Danger cutoff (INCLUSIVE) is a cross-surface invariant — hospital "Maintenance contracts" + founder "Expiring AMC" both pin to the same boundary.

## Verification checklist

- `./gradlew :app:testDebugUnitTest` — green.
- `./gradlew :app:lintDebug` — green (lint debug task, 0 errors).
- `./gradlew :app:assembleDebug` — APK at `app/build/outputs/apk/debug/`.
- `./gradlew :app:assembleRelease` — R8-minified APK (release signing config required for AAB).

## Blockers / known deferred work

- AGP + KSP toolchain upgrade — bundled, awaiting a coordinated bump alongside Hilt KSP processor + Compose compiler.
- `targetSdk = 35` → 36 once Android 16 stable. Not blocking the v1 Play Store deadline.
- `CredentialManagerSignInWithGoogle` lint warning — `googleid` 1.1.1 expects an updated credential type check; deferred to the next googleid bump.
- 105 GradleDependency minor/patch bumps — handled by Dependabot weekly sweeps (configured but yet to land any PRs).

## Release

Signed AAB is produced by `release-aab.yml` on `v*` tag push. Required repo secrets are listed at the top of that workflow. Upload the AAB attached to the GitHub Release to Play Console.
