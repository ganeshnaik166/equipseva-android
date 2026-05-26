# App Links deployment — `assetlinks.json` hosting

## Why this matters

`AndroidManifest.xml` declares an `autoVerify="true"` intent filter for HTTPS
URLs on `equipseva.com` (and `www.equipseva.com`) under the following paths:

- `/job/…`           — repair-job detail (deep link from a notification or share)
- `/chat/…`          — chat conversation (deep link from a notification)
- `/engineer/…`      — engineer public profile
- `/engineers`       — engineer directory landing
- `/notifications`   — in-app notifications list

When Android installs the app, it fetches `https://equipseva.com/.well-known/assetlinks.json`
and verifies the listed SHA-256 fingerprint against the installed APK. If the
fingerprint matches, every URL on those paths opens the app directly (no
chooser dialog, no other app can claim them).

- **With the file hosted**: only EquipSeva's signed APK receives the intent.
- **Without the file**: verification fails silently. Android falls back to the
  standard intent-chooser flow, where any other app that declares the same
  filter can compete for the link.

Path filters in the manifest are deliberately tight — `/privacy`, `/terms`,
`/refund`, `/licenses`, `/auth/reset`, and any other path not in the list
above falls through to the browser. Keep the filters in sync with
[`DeepLinkRouter.routeForParts`](../../app/src/main/kotlin/com/equipseva/app/navigation/DeepLinkRouter.kt).

## What is NOT an App Link

- **Razorpay payment return** — the Standard Checkout SDK uses in-process
  callbacks (`MainActivity.onPaymentSuccess` / `onPaymentError`). No web
  redirect; the `/pay/return` filter that lived here through PR #152 was
  removed once the SDK callback path proved stable. No re-introduction
  planned for v1.
- **OAuth callbacks (`equipseva://auth-callback`)** — intentionally not
  registered. The custom scheme is squattable by other apps; current auth
  flows (password, OTP-by-code, Google ID token via Credential Manager)
  don't need a callback URL. Magic-link / OAuth redirects, if added later,
  should go on an App Link path (e.g. `/auth/callback`) — the assetlinks
  statement covers all paths on the host with no restriction.

## Canonical file location

The repo holds the source of truth at:

```text
docs/.well-known/assetlinks.json
```

It is served by GitHub Pages (source = `main:/docs`) at:

```text
https://equipseva.com/.well-known/assetlinks.json
```

Three mirrors exist for documentation and alternate-hosting plans
(`docs/security/assetlinks.json`, `well-known/.well-known/assetlinks.json`,
`website/.well-known/assetlinks.json`). They are kept byte-identical by
`scripts/sync-assetlinks.sh` — the `Check assetlinks.json` CI workflow
refuses any PR where they drift. A separate `play-store/assetlinks.json`
exists for Play Console upload reference (prod-only entry) and is
intentionally NOT synced.

## Current entries (2 packages)

1. `com.equipseva.app` — release/upload-key signing fingerprint (extracted
   2026-04-24 from `app/equipseva-upload.jks`).
2. `com.equipseva.app.debug` — local Android debug keystore fingerprint
   (from `~/.android/debug.keystore`). Debug builds use this so App Links
   can be tested locally without a release build.

After the first AAB upload to Play (see [LAUNCH_INFRA.md §3](LAUNCH_INFRA.md#3-expected_cert_sha256--paste-play-app-signing-fingerprint)),
append a second fingerprint to the `com.equipseva.app` target's
`sha256_cert_fingerprints` array — see [Issue #303](https://github.com/ganeshnaik166/equipseva-android/issues/303)
for the exact procedure. The script handles propagating to mirrors.

## Hosting requirements (Google's verifier)

- **HTTPS only**, no redirects (must return 200 directly, not 3xx).
- **Content-Type**: `application/json`.
- Accessible **without any authentication** (no cookies, no bearer).
- **No charset** in the Content-Type (serve as `application/json`, not
  `application/json; charset=utf-8` — check with `curl -I`).

GitHub Pages serves `.json` files with the correct content-type by default.

## Live verification

```bash
# Confirm file is live + correct content-type
curl -I https://equipseva.com/.well-known/assetlinks.json
# expect: HTTP/2 200, content-type: application/json

# Confirm Google's verifier sees the statements (no auth needed)
curl -s 'https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https%3A%2F%2Fequipseva.com&relation=delegate_permission%2Fcommon.handle_all_urls' | jq
# expect: both com.equipseva.app + com.equipseva.app.debug in the result
```

## Device-side verification

After the file is live, install a fresh APK on a device and run:

```bash
adb shell pm verify-app-links --re-verify com.equipseva.app
adb shell pm get-app-links com.equipseva.app
```

The output for `equipseva.com` should show `verified`. If it shows `none` or
`legacy_failure`, Android couldn't fetch or parse the manifest — check HTTPS,
Content-Type, redirects.

## Play App Signing (required before public release)

Play App Signing re-signs the AAB with a Play-managed key before distribution.
The on-device SHA-256 then becomes Google's key, not the upload key in this
repo. App Links for Play-distributed builds will fail verification until the
Play SHA-256 is added to `assetlinks.json`. See [Issue #303](https://github.com/ganeshnaik166/equipseva-android/issues/303).

## Key-rotation hygiene

If the release keystore is ever lost, rotated, or enrolled in Play App Signing
Key Upgrade, add the new fingerprint to the array and keep the old one for a
migration window (so already-installed builds still verify). Never remove a
fingerprint until every user has upgraded past it.
