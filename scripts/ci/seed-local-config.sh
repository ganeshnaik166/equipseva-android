#!/usr/bin/env bash
# Seeds the two gitignored files a compile-only CI build needs. BuildConfig
# fields fall back to empty strings (no network is made); the placeholder
# google-services.json satisfies the Firebase Gradle plugin for both the
# release (com.equipseva.app) and debug (.debug suffix) application IDs.
# Shared by android.yml and roborazzi.yml so the two can't drift.
set -euo pipefail
cd "$(dirname "$0")/../.."

cat > local.properties <<'PROPS'
SUPABASE_URL=
SUPABASE_ANON_KEY=
SENTRY_DSN=
GOOGLE_WEB_CLIENT_ID=
EXPECTED_CERT_SHA256=
MAPS_API_KEY=
PROPS

cat > app/google-services.json <<'JSON'
{
  "project_info": {
    "project_number": "000000000000",
    "project_id": "equipseva-ci-placeholder",
    "storage_bucket": "equipseva-ci-placeholder.appspot.com"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "1:000000000000:android:0000000000000000000000",
        "android_client_info": { "package_name": "com.equipseva.app" }
      },
      "api_key": [{ "current_key": "AIzaSyAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" }]
    },
    {
      "client_info": {
        "mobilesdk_app_id": "1:000000000000:android:0000000000000000000000",
        "android_client_info": { "package_name": "com.equipseva.app.debug" }
      },
      "api_key": [{ "current_key": "AIzaSyAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" }]
    }
  ],
  "configuration_version": "1"
}
JSON
chmod +x gradlew
echo "seeded local.properties + app/google-services.json"
