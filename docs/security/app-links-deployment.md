# App Links deployment — `/pay/return` binding

## Why this matters

`AndroidManifest.xml` declares an intent filter for `https://equipseva.com/pay/return`
with `android:autoVerify="true"`. Android verifies that association against a
Digital Asset Links manifest hosted at
`https://equipseva.com/.well-known/assetlinks.json`.

- **With the file hosted**: only EquipSeva's signed APK receives the intent. The
  OS auto-opens our app, no chooser dialog. Malicious apps cannot claim the URL.
- **Without the file**: verification fails silently. Android falls back to the
  standard intent-chooser flow, where any other app that declares the same
  filter can compete for the link. A rogue app could harvest `order_id` values
  from the payment-return callback, or race ours to open first.

The callback only carries a UUID (no secrets; RLS blocks unauthorized reads),
so impact is limited to UI-hijack / confusion. But we already set
`autoVerify="true"`, so deploying the manifest is the cheap final step.

## File to deploy

[`docs/security/assetlinks.json`](./assetlinks.json) in this repo.

Contains two entries:

1. `com.equipseva.app` — the release/upload-key signing fingerprint
   (extracted 2026-04-24 from `app/equipseva-upload.jks`).
2. `com.equipseva.app.debug` — the local Android debug keystore fingerprint
   (from `~/.android/debug.keystore`). Debug builds use this so App Links can
   also be tested locally without a release build. Remove this entry if you
   don't want debug builds to compete for the URL on user devices.

## Deploy target

Host the file **exactly** at:

```
https://equipseva.com/.well-known/assetlinks.json
```

Google's requirements:

- **HTTPS only**, no redirects (must return 200 directly, not 3xx).
- **Content-Type**: `application/json`.
- Accessible **without any authentication** (no cookies, no bearer).
- **No charset** in the Content-Type (serve as `application/json`, not
  `application/json; charset=utf-8` — some hosts add this automatically;
  check with `curl -I`).

Once hosted, Google's public verifier:

```
https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https%3A%2F%2Fequipseva.com&relation=delegate_permission%2Fcommon.handle_all_urls
```

should return a successful statement list for both package names.

## Device-side verification

After the file is live, install a fresh APK on a device and run:

```bash
adb shell pm verify-app-links --re-verify com.equipseva.app
adb shell pm get-app-links com.equipseva.app
```

The output for `equipseva.com` should show `verified`. If it shows `none` or
`legacy_failure`, Android couldn't fetch or parse the manifest — check HTTPS,
Content-Type, redirects.

## Play App Signing (required before release)

If the app is uploaded via Play App Signing (recommended and likely required
on new Play Console apps), **Google re-signs the AAB with a Play-managed key
before distribution**. The on-device SHA-256 is then Google's key, not the
upload key in this repo.

Before shipping to Play:

1. Upload the first AAB to Play Console.
2. Go to **Release → Setup → App integrity → App signing**.
3. Copy the `SHA-256 certificate fingerprint` under **App signing key
   certificate** (NOT the upload key — that one is already in this file).
4. Append a third entry to `sha256_cert_fingerprints` **inside the existing
   `com.equipseva.app` target** (same target, add to the array):

```json
"sha256_cert_fingerprints": [
  "92:B9:05:A8:19:7D:0C:54:E2:91:8B:27:75:DD:9A:F8:C9:A6:F5:13:8F:8C:59:17:77:80:FD:DF:67:A2:D1:C1",
  "<PLAY-APP-SIGNING-SHA256-HERE>"
]
```

5. Re-deploy the manifest. Run the Google verifier + `adb` checks again.

Without this, App Links for Play-distributed builds will fail verification
because the on-device signature won't match any listed fingerprint.

## Key-rotation hygiene

If the release keystore is ever lost, rotated, or enrolled in Play App Signing
Key Upgrade, add the new fingerprint to the array and keep the old one for a
migration window (so already-installed builds still verify).

Never remove a fingerprint until every user has upgraded past it.

## Custom-scheme OAuth callback (follow-up)

`equipseva://auth-callback` in the manifest is a custom scheme, which is
squattable by other apps. Supabase's Kotlin SDK uses PKCE by default, so
intercepting the scheme doesn't let an attacker exchange the code — but it's
still best practice to migrate to an App Link:

1. Change the `<data>` element on that intent filter to
   `android:scheme="https" android:host="equipseva.com" android:pathPrefix="/auth/callback"`
   and add `android:autoVerify="true"`.
2. Update the Supabase redirect URL in **Supabase Dashboard → Authentication
   → URL Configuration → Redirect URLs** to the new HTTPS URL.
3. The existing `assetlinks.json` already covers all URLs on `equipseva.com`
   for the package (no path restriction in the asset-links statement), so no
   changes to this file are needed.

This migration touches Supabase dashboard + code + deploy infrastructure —
tracked as a follow-up, not part of this PR.
