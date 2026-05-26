---
title: Open-source licenses
permalink: /licenses/
redirect_from:
  - /open-source/
  - /open-source-licenses/
  - /launch/OPEN_SOURCE_LICENSES/
  - /launch/OPEN_SOURCE_LICENSES.html
---

# Open-source licenses

The EquipSeva Android app uses the following third-party libraries. Each is distributed under its own license; the full text of every license referenced here is included in the corresponding upstream repository.

**Last updated:** 2026-05-26

---

## Apache License 2.0

The majority of the app's dependencies are distributed under the Apache License, Version 2.0. The full license text is available at <https://www.apache.org/licenses/LICENSE-2.0>.

- **Android Jetpack** (AndroidX libraries — Compose, Room, Lifecycle, Navigation, WorkManager, DataStore, Security-Crypto, Credentials, Activity, ExifInterface) — Copyright © Google LLC.
- **Kotlin** (kotlin-stdlib, kotlinx-coroutines, kotlinx-serialization) — Copyright © JetBrains s.r.o.
- **Hilt / Dagger** — Copyright © Google LLC.
- **Coil** (image loading) — Copyright © Coil Contributors.
- **Ktor** (HTTP client used by Supabase SDK) — Copyright © JetBrains s.r.o.
- **OkHttp / Okio** (Ktor's HTTP engine) — Copyright © Square, Inc.
- **Google Play Services** (Maps, Location, Integrity) — Copyright © Google LLC.
- **Google Material Components / Material Design Icons** — Copyright © Google LLC.
- **Firebase Android SDK** (Messaging, Crashlytics) — Copyright © Google LLC. _(Note: Firebase usage is also governed by the Firebase Terms of Service.)_

## MIT License

Distributed under the MIT License. The full license text is available at <https://opensource.org/licenses/MIT>.

- **Supabase Kotlin SDK** (auth, postgrest, realtime, storage, functions, bom) — Copyright © Supabase Inc.
- **Sentry Android SDK** — Copyright © Functional Software, Inc. dba Sentry.

## BSD 3-Clause License

Distributed under the BSD 3-Clause License. The full license text is available at <https://opensource.org/licenses/BSD-3-Clause>.

- **SQLCipher for Android** (`net.zetetic:sqlcipher-android`) — Copyright © Zetetic LLC. Provides 256-bit AES encryption at rest for the app's local SQLite database.

## Proprietary / Commercial Terms

The following components are integrated under their respective vendor agreements and are not redistributable under an open-source license:

- **Razorpay Standard Checkout SDK** (`com.razorpay:checkout`) — Copyright © Razorpay Software Private Limited. Used under the Razorpay SDK Terms of Service.

---

## App source code

The EquipSeva Android app source code itself is proprietary. The app's behavior, UI, branding, and business logic remain the intellectual property of the EquipSeva team — see the [Terms of Service](/terms/) for the user-facing licence grant.

## Reporting an issue

If you believe a third-party component is missing from this list or attributed incorrectly, please email <security@equipseva.com> and we will correct it promptly.
