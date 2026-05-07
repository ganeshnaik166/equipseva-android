# v2.1 activation runbook

The v2.1 anti-disintermediation moat (PRs #270 – #319) is fully on `main` and live on prod Supabase. Everything below is dashboard-only work that the founder must do — code can't reach into Razorpay, Exotel, Cloudflare, GitHub Settings, or Play Console.

Tick each item as you go. Estimated total time: **~45 minutes** if you have all dashboard logins handy.

---

## 1. Rotate Razorpay live keys (~5 min)

Live keys (`rzp_live_*`) were pasted in chat on 2026-05-06 → treat as exposed.

1. Razorpay Dashboard → Account → API Keys → **Regenerate Live Key**.
2. Copy the new `key_id` + `key_secret`.
3. Push to Supabase secrets:

   ```bash
   supabase secrets set RAZORPAY_KEY_ID=rzp_live_<new>
   supabase secrets set RAZORPAY_KEY_SECRET=<new-secret>
   ```

4. Smoke: kick off a ₹1 escrow on prod and confirm `pay_*` lands in Razorpay dashboard. Roll back if needed.

---

## 2. Rotate Exotel keys (~5 min)

Same exposure. Same fix path.

1. Exotel Dashboard → API → **Regenerate API Key + Token**.
2. Push:

   ```bash
   supabase secrets set EXOTEL_API_KEY=<new>
   supabase secrets set EXOTEL_API_TOKEN=<new>
   ```

3. Smoke: from the engineer profile, tap "Call hospital" — should hit the request-call-session edge fn (no 503 / no auth error).

---

## 3. Add tester phones to Exotel Address Book (~5 min)

Exotel **trial** accounts can only call Address Book numbers. Calls to anyone else 400.

1. Exotel Dashboard → Address Book → **Add contact** → tester phone(s) (with country code).
2. Address Book takes a couple of minutes to propagate.
3. Once tester verify works, the trial → paid upgrade unlocks calls to anyone (~₹500/mo + per-second talk).

---

## 4. Activate the cron-tick GitHub workflow (~2 min)

PR-D39 shipped the workflows; they need the secret to run.

1. GitHub repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**.
2. Name: `CRON_TICK_SECRET`. Value: the same string you set as the Supabase `CRON_TICK_SECRET` secret.
3. (Optional) Manually trigger once to confirm: **Actions** tab → **cron-tick (hourly)** → **Run workflow**. Should return 200.

After this, hourly + daily housekeeping (escrow auto-release, cost-revision expiry, TTL purges) runs automatically. No more manual `slot=hourly` POSTs.

---

## 5. Pre-Play-Store hardening (~20 min)

These have to be done locally before the AAB is built.

### 5a. Fill `EXPECTED_CERT_SHA256` in `local.properties`

Computes the upload-keystore's SHA-256 in the format `SignatureVerifier` expects (base64 of raw 32-byte digest, NOT the colon-hex):

```bash
# Run from repo root. Replace <STOREPASS> with the keystore password.
keytool -list -v \
  -keystore app/equipseva-upload.jks \
  -alias equipseva-upload \
  -storepass <STOREPASS> \
  | grep -A 1 "SHA256:" | head -2
```

Take the colon-separated hex line, strip colons, hex-decode to bytes, base64-encode:

```bash
HEX="92:B9:05:A8:..."   # paste from keytool output
echo "$HEX" | tr -d ':' | xxd -r -p | base64
```

Add to `local.properties`:

```properties
EXPECTED_CERT_SHA256=<base64-44-chars>
```

Re-run `scripts/pre-release-checks.sh` — should pass.

### 5b. Enable HaveIBeenPwned leaked-password check

One checkbox. Cannot be done via CLI.

- Supabase Dashboard → **Authentication** → **Policies** → **Password Strength** → enable **Prevent use of leaked passwords**.

### 5c. After first AAB upload, append Play App Signing SHA to assetlinks

Google re-signs distributed APKs with their own key. That key's SHA-256 must be added to `website/.well-known/assetlinks.json` for App Links to keep verifying.

1. Upload first AAB to Play Console (Internal testing track is fine).
2. Play Console → **Release** → **Setup** → **App integrity** → **App signing** → copy the SHA-256 of the **App signing key certificate**.
3. Edit `website/.well-known/assetlinks.json` — add the new SHA into the existing `sha256_cert_fingerprints` array on the `com.equipseva.app` target.
4. Re-deploy the website. Verify with:

   ```bash
   curl -fsSL https://equipseva.com/.well-known/assetlinks.json | jq '.[].target.sha256_cert_fingerprints'
   ```

5. On a Play-installed build, run:

   ```bash
   adb shell pm get-app-links com.equipseva.app
   ```

   Should print `equipseva.com: verified`.

### 5d. Play Console assets

The actual content lives at:

- Privacy: `https://equipseva.com/privacy/`
- Terms: `https://equipseva.com/terms/`
- Refunds: `https://equipseva.com/refunds/`

Play Console fields to fill:

- Privacy Policy URL ← `https://equipseva.com/privacy/`
- Data-safety form ← cross-reference [data-safety doc](DATA_SAFETY.md)
- Content rating questionnaire
- Store listing assets (icon, screenshots, feature graphic) ← per [STORE_LISTING.md](STORE_LISTING.md)

---

## 6. Fix `www.equipseva.com` Cloudflare redirect (~5 min, low priority)

App Links to apex (`equipseva.com`) verify; `www.equipseva.com` returns code 1024 (no response) because Cloudflare 301-redirects www → apex before serving `assetlinks.json`.

1. Cloudflare → DNS → ensure `www` is a CNAME or A record (not a Page Rule redirect).
2. Cloudflare → Rules → either remove the www → apex redirect, or scope it to exclude `/.well-known/*`.
3. Verify:

   ```bash
   adb shell pm get-app-links com.equipseva.app | grep www
   ```

   Should print `www.equipseva.com: verified`.

This is *low priority* — apex already verifies, so the App Link works. Only matters if you ever publish a `www.equipseva.com/...` URL.

---

## Done state

After all items above, the v2.1 product is fully activated:

- Live Razorpay charges with rotated keys
- Live Exotel masked calls with rotated keys + paid Address Book
- Free-tier scheduling running automatically via GitHub Actions
- Release builds enforce anti-repackaging via `EXPECTED_CERT_SHA256`
- HIBP leaked-password check on
- Play App Signing key verified in assetlinks
- Play Console listing complete
- App Links verify on both apex + www

Done.
