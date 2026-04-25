# scripts/

Operational scripts that run **outside** the Android build — DNS, signing, Play-launch wiring. Each script self-documents in its header; this file is the index.

| Script | Purpose | When to run |
|---|---|---|
| [`setup_godaddy_dns.sh`](setup_godaddy_dns.sh) | Idempotently point `equipseva.com` at GitHub Pages via the GoDaddy DNS API. Replaces the apex A records (deletes WebsiteBuilder parking), adds AAAA, points the `www` CNAME at `<owner>.github.io`. | Once, when the domain is first registered or moved registrars. |
| [`compute_signing_sha.sh`](compute_signing_sha.sh) | Print a signing certificate's SHA-256 in hex, hex-plain, and base64 forms. Modes: `--hex`, `--keystore --alias`, `--apk`. | After the first AAB upload — convert the Play Console SHA into the base64 form `BuildConfig.EXPECTED_CERT_SHA256` expects. |
| [`update_assetlinks.sh`](update_assetlinks.sh) | Rewrite `docs/.well-known/assetlinks.json` with a new production-package SHA-256, preserving the debug entry by default. | After the first AAB upload — bind the App Link `https://equipseva.com/pay/return` to the release signing certificate. |

All scripts are POSIX-`bash` and idempotent. Re-running is safe; nothing destructive happens twice.

## Required environment

Most scripts need credentials passed via env vars; never commit them. The repo's `.gitignore` covers the obvious files (`.env`, `local.properties`, `keystore.properties`, `*.jks`).

| Var | Used by | Source |
|---|---|---|
| `GODADDY_KEY` / `GODADDY_SECRET` | `setup_godaddy_dns.sh` | https://developer.godaddy.com/keys (Production environment) |
| `ANDROID_HOME` | `compute_signing_sha.sh --apk` (falls back to `~/Library/Android/sdk`) | local Android SDK install |

## Quick reference — full launch wiring

```bash
# 1. Domain → GitHub Pages.
GODADDY_KEY=... GODADDY_SECRET=... bash scripts/setup_godaddy_dns.sh

# 2. After first AAB upload, convert Play Console SHA to base64.
bash scripts/compute_signing_sha.sh --hex AB:CD:EF:...

# 3. Update assetlinks with the production SHA.
bash scripts/update_assetlinks.sh AB:CD:EF:...
git add docs/.well-known/assetlinks.json
git commit -m "Bind App Link to production signing SHA-256"
git push origin main
```

See [docs/launch/LAUNCH_CHECKLIST.md](../docs/launch/LAUNCH_CHECKLIST.md) for the end-to-end runbook.
