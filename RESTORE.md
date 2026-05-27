# Disaster recovery — rebuilding EquipSeva on a fresh machine

What to do if the dev laptop is lost/wiped. **This file contains no secrets.**

## What lives where

| Artifact | Home(s) | Notes |
|---|---|---|
| Source code | This public GitHub repo | Always recoverable via `git clone`. |
| Upload signing key (`.jks`) | GitHub Actions secrets (`KEYSTORE_BASE64`) + your encrypted Drive backup | **Irreplaceable.** Never committed (repo is public). |
| Keystore passwords | GH secrets (`KEYSTORE_STORE_PASSWORD`, `KEYSTORE_KEY_PASSWORD`, `KEYSTORE_KEY_ALIAS`) + encrypted backup | |
| Build config (`local.properties`) | GH secrets (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `RAZORPAY_KEY`, `MAPS_API_KEY`, `EXPECTED_CERT_SHA256`) | Reconstructable from secrets. |
| `app/google-services.json` | Firebase console (re-download) + encrypted backup | Regenerable any time. |
| Backend / data | Supabase project `eyswaywvtartpvtoxtdr` | Not on the laptop. |

## Fastest recovery: ship without touching local files

The signed release is built entirely from GitHub Actions secrets — no local keystore needed:

```bash
git clone https://github.com/ganeshnaik166/equipseva-android
cd equipseva-android
git tag v0.1.0 && git push --tags     # release-aab.yml builds + signs the AAB
```

Download the signed `.aab` from the resulting GitHub Release and upload it to Play Console.

## Full local rebuild (when you want to build on the new machine)

1. `git clone` the repo.
2. Restore the gitignored files from your encrypted Drive backup:
   ```bash
   openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 \
     -in equipseva-secrets-backup-*.tar.gz.enc | tar -xzf -
   ```
   (passphrase is in your password manager)
3. Place the restored files:
   - `equipseva-upload.jks` → `app/`
   - `keystore.properties` → `app/`
   - `local.properties` → repo root
   - `google-services.json` → `app/`
4. Build: `./gradlew :app:bundleRelease`

If the encrypted backup is also gone, recreate `local.properties` from the GitHub Actions
secrets, re-download `google-services.json` from Firebase, and (worst case) reset the Play
**upload** key via Play Console → App integrity (Play App Signing makes the upload key
resettable; the app-signing key Google holds is unaffected).

## Keystore facts

- Alias: `equipseva-upload`
- Used by: `app/build.gradle.kts` (reads `app/keystore.properties`) and `.github/workflows/release-aab.yml`.
- The SHA-256 that ends up in `assetlinks.json` + `EXPECTED_CERT_SHA256` after first upload is
  Google's **App Signing** key, not this upload key — see `docs/launch/V21_ACTIVATION_RUNBOOK.md` §5c.
