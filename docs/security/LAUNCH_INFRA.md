# Pre-Play-Store launch infra runbook

Four user-side tasks that the code can't do for you. Knock out in this
order — items 1 + 4 are pure copy/paste; 2 is a single dashboard
checkbox; 3 is one-shot after the first AAB upload.

Total wall-clock: ~30 minutes if Play Console is already set up.

---

## 1. Host `assetlinks.json` at `https://equipseva.com/.well-known/assetlinks.json`

**Why:** the `/pay/return` deep link in `AndroidManifest.xml` declares
`android:autoVerify="true"`. Without the file hosted, Android falls
back to the chooser dialog and any rogue app declaring the same filter
can race to harvest `order_id`. See `app-links-deployment.md` for full
threat model.

**Deploy:** the `well-known/` directory at the repo root is a tiny
static site ready to push to Vercel / GitHub Pages / Cloudflare.

```bash
cd well-known
npx vercel --prod
# Link to or create a Vercel project, attach the apex domain
# equipseva.com (or a subdomain you alias). vercel.json pins
# Content-Type: application/json on the well-known path.
```

Or follow the GitHub Pages / Cloudflare Pages / existing-webserver
options in `well-known/README.md`.

**Verify:**

```bash
curl -I https://equipseva.com/.well-known/assetlinks.json
# expect: 200, content-type: application/json (no charset suffix)

curl -s 'https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https%3A%2F%2Fequipseva.com&relation=delegate_permission%2Fcommon.handle_all_urls' | jq
# expect: statements array, both com.equipseva.app + com.equipseva.app.debug
```

After the first AAB upload to Play (item 3 below), append the Play App
Signing key SHA-256 to BOTH `well-known/assetlinks.json` AND
`docs/security/assetlinks.json` under the `com.equipseva.app` target,
re-deploy. Without that, Play-distributed installs fail App Link
verification.

---

## 2. Enable HaveIBeenPwned password check on Supabase

**Why:** prevents users registering with passwords that have appeared
in known breaches. One-checkbox feature on Supabase.

```
Supabase Dashboard
  → Project: equipseva
  → Authentication
  → Policies (left nav)
  → Password Strength
  → ☑ Prevent use of leaked passwords
```

That's the entire task. Cannot be done via MCP — has to be a manual
dashboard click.

**Verify:** in the Supabase advisors panel the only remaining WARN
under "Password security" should disappear.

---

## 3. `EXPECTED_CERT_SHA256` — paste Play App Signing fingerprint

**Why:** `SignatureVerifier` (round 13) accepts a comma-separated list
of SHA-256 fingerprints so both the upload key (used locally / for
sideload installs) and the Play App Signing key (used by Play-
distributed installs) pass anti-tamper. Until the constant is filled,
the verifier returns `Verdict.Unknown` — non-blocking but the anti-
tamper guard is silently off.

**Step 0 — extract the upload-key fingerprint** (do this once, locally):

```bash
keytool -list -v \
  -keystore app/equipseva-upload.jks \
  -alias equipseva-upload \
  -storepass <YOUR-KEYSTORE-PASSWORD> \
  | grep 'SHA256:' \
  | head -1 \
  | awk '{print $2}' \
  | tr -d ':' \
  | xxd -r -p \
  | base64
# Copy the base64 output — that's the value SignatureVerifier compares.
```

Store as `EXPECTED_CERT_SHA256_UPLOAD` in your password manager — same
value goes into `assetlinks.json` (already there) and Play Console
when registering the upload key.

**Step 1 — upload first AAB to Play Console.**

**Step 2 — extract the Play App Signing fingerprint:**

```
Play Console
  → equipseva
  → Release → Setup → App integrity → App signing
  → "App signing key certificate"
  → Copy SHA-256 fingerprint (colon-separated hex like AA:BB:CC:...)
```

Convert the colon-hex to the same base64 format:

```bash
echo 'AA:BB:CC:DD:...' | tr -d ':' | xxd -r -p | base64
```

**Step 3 — wire both fingerprints:**

In `local.properties` (your dev box):

```properties
EXPECTED_CERT_SHA256=<UPLOAD_BASE64>,<PLAY_BASE64>
```

In CI (GitHub Actions secrets / equivalent):

```
EXPECTED_CERT_SHA256 = <UPLOAD_BASE64>,<PLAY_BASE64>
```

The build's `localOrEnv("EXPECTED_CERT_SHA256")` picks up either path
(`app/build.gradle.kts:55`).

**Step 4 — add Play SHA-256 to `assetlinks.json`** (same value, but as
colon-hex form, into the `sha256_cert_fingerprints` array in BOTH
`well-known/assetlinks.json` and `docs/security/assetlinks.json`).
Re-deploy `well-known/`.

**Step 5 — flip enforcement** when ready (release build only):

`SignatureVerifier.kt` is wired report-only today (`Verdict.Unknown`
on blank constant; `Verdict.Tampered` when filled but mismatched).
Once the constants are populated and a release AAB is verified to
pass, search for `TamperPolicy.enforce` and flip the flag so the
mismatch path actually wipes session + shows the "not authorized"
screen.

---

## 4. `INGEST_OPENFDA_SECRET` — gate the catalog ingest edge function

**Why:** round 22 added a `x-webhook-secret` check to the
`ingest_openfda` edge function. Without `INGEST_OPENFDA_SECRET` set on
the Supabase dashboard, the function fails closed (every call
returns 401). That's a safe default — but if you ever want to re-run
catalog ingest, set the secret + invoke with the matching header.

If you're **not using the catalog ingest** for v1 (marketplace
sunset), leave it unset and skip this entire section. The function is
effectively disabled until you do.

**Otherwise:**

```bash
# Generate a strong random secret (64 hex chars):
openssl rand -hex 32
# example: 6e06f912c5931e305340b9612225071f84190fc60c28c1a8b82e1bc450840851
```

```
Supabase Dashboard
  → Project: equipseva
  → Edge Functions
  → Manage secrets
  → Add: INGEST_OPENFDA_SECRET = <openssl-output>
```

**Invoke:**

```bash
curl -X POST 'https://eyswaywvtartpvtoxtdr.supabase.co/functions/v1/ingest_openfda?max=500' \
  -H 'x-webhook-secret: <openssl-output>'
```

---

## Final pre-launch checklist

- [ ] `assetlinks.json` returns 200 with `application/json` at the
      well-known URL
- [ ] Both upload + Play App Signing SHA-256 fingerprints listed in
      that file
- [ ] HIBP toggle enabled in Supabase Auth
- [ ] `EXPECTED_CERT_SHA256` populated in `local.properties` AND CI
      secret with both fingerprints comma-joined
- [ ] `adb shell pm get-app-links com.equipseva.app` shows `verified`
      for `equipseva.com`
- [ ] (optional) `INGEST_OPENFDA_SECRET` set if catalog ingest is in
      scope

After all items: Play Console → Release → Internal testing → upload
the first AAB → invite test users.
