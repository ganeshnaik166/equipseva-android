# EquipSeva v1 — Play Store launch checklist

End-to-end runbook from "code is done" to "app is live in Play Store". Code work is complete (PRs #148–#196). Everything below is external work + a one-shot wiring step.

Tick items as you complete them.

---

## 1. Publish policies + assetlinks under equipseva.com (~10 min)

The repo is wired to publish via **GitHub Pages** at `equipseva.com` (CNAME shipped at `docs/CNAME`). After flipping the Pages toggle and pointing DNS, every URL below resolves automatically.

### Step-by-step

1. Open the repo on GitHub → **Settings** → **Pages**.
2. Under **Build and deployment**:
   - Source: **Deploy from a branch**
   - Branch: **`main`**
   - Folder: **`/docs`**
3. Click **Save**. First build takes ~1–2 minutes.
4. Under **Custom domain**, GitHub auto-detects `equipseva.com` from `docs/CNAME` and runs DNS verification.
5. Configure the DNS at your registrar:
   - A records for `equipseva.com` → `185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153`
   - AAAA records for `equipseva.com` → `2606:50c0:8000::153`, `2606:50c0:8001::153`, `2606:50c0:8002::153`, `2606:50c0:8003::153`
   - CNAME for `www.equipseva.com` → `<owner>.github.io`
   See [GitHub's apex-domain docs](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site#configuring-an-apex-domain) if anything looks unfamiliar.
6. Wait for the Pages dashboard to mark the cert as **Issued** (~5–15 min once DNS resolves), then tick **Enforce HTTPS**.

### Resulting public URLs (paste these into Play Console + the App)

| Purpose | URL |
|---|---|
| Privacy Policy | `https://equipseva.com/privacy/` |
| Terms of Service | `https://equipseva.com/terms/` |
| Refund Policy | `https://equipseva.com/refunds/` |
| App Links assetlinks | `https://equipseva.com/.well-known/assetlinks.json` |
| Landing | `https://equipseva.com/` |

### Why the assetlinks file matters

App Link binding for the Razorpay payment-return deep link (`https://equipseva.com/pay/return`) requires the SHA-256 of the signing certificate to be served at `/.well-known/assetlinks.json`. The repo serves it from `docs/.well-known/assetlinks.json`. **After Step 7 of this runbook (post-first-Play-upload), update that file with the App-Signing SHA-256 from Play Console — see §7.**

### Alternative hosts (if you'd rather not use Pages)

- **Notion** — paste each MD file into a public page (loses the assetlinks endpoint).
- **Vercel** — point a project at `docs/` with `framework: jekyll`. Set `equipseva.com` as the production domain. Same DNS records, different vendor.

### Before publishing — verify the defaults

The policies are filled with these defaults — edit before publishing if any are wrong:

- Grievance Officer: **Ganesh Dhanavath** · grievance@equipseva.com
- Registered address: **EquipSeva, Hyderabad, Telangana, India**
- Jurisdiction: **Hyderabad, Telangana**

If you operate from a different city or want a different grievance officer, edit `docs/launch/PRIVACY_POLICY.md`, `TERMS_OF_SERVICE.md`, and `REFUND_POLICY.md` accordingly.

Source files:
- [PRIVACY_POLICY.md](./PRIVACY_POLICY.md)
- [TERMS_OF_SERVICE.md](./TERMS_OF_SERVICE.md)
- [REFUND_POLICY.md](./REFUND_POLICY.md)

---

## 2. Get the design assets ready (needs a designer)

- [ ] **App icon** — confirm `app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` is final brand art. If not, replace + commit. Provide a 512×512 PNG master to Play.
- [ ] **Feature graphic** — 1024×500 PNG. Brand banner with tagline.
- [ ] **8+ phone screenshots** — 1080×1920 (or 1920×1080). Suggested order in [STORE_LISTING.md](./STORE_LISTING.md#screenshots-need-design-output).

Easiest path if no designer: use Figma's "Smart Animate" Play-Store templates + your real running app as source. A junior designer can do it in a day.

---

## 3. Create test accounts for Play review (~10 min)

- [ ] Create one **hospital** test account. Skip KYC (not needed for hospital role).
- [ ] Create one **engineer** test account that has **already passed KYC**. Use a real-looking but synthetic ID document; fast-path-approve via Supabase.
- [ ] Note credentials — you'll paste them in App Access below.

---

## 4. Razorpay live-mode setup (needs Razorpay support if not already done)

- [ ] Enable **live mode** for the EquipSeva merchant account.
- [ ] Refund Policy URL submitted to Razorpay support (they need it on file).
- [ ] Webhook endpoint verified end-to-end.

---

## 5. Real-device end-to-end test (1–2 hours)

- [ ] Install the latest debug APK on a real Android device (not emulator).
- [ ] Sign up as a hospital, place a spare-part order, complete payment via **Razorpay test mode**.
- [ ] Confirm the `https://equipseva.com/pay/return?order_id=…` deep-link returns to the app and shows order status.
- [ ] Place a second order, cancel it, confirm refund status flows through Razorpay test dashboard.
- [ ] Sign up as an engineer, complete KYC, bid on a job, confirm escrow + payout flow.

---

## 6. Play Console — first upload (~1 hour)

- [ ] **App content → Target audience and content** — answers in [CONTENT_RATING.md](./CONTENT_RATING.md#target-audience-and-content).
- [ ] **App content → Ads** — answer **No**.
- [ ] **App content → Content rating** — run the IARC questionnaire using [CONTENT_RATING.md](./CONTENT_RATING.md).
- [ ] **App content → Privacy Policy** — paste hosted Privacy Policy URL.
- [ ] **App content → Data safety** — fill the form using [DATA_SAFETY.md](./DATA_SAFETY.md).
- [ ] **App content → App access** — provide test credentials from §3.
- [ ] **Main store listing** — paste copy from [STORE_LISTING.md](./STORE_LISTING.md).
- [ ] **Main store listing → Graphics** — upload icon, feature graphic, 8 screenshots.
- [ ] **Production → Create new release** — upload the signed AAB built from `chore/wire-release-signing-config` (or equivalent release branch).

---

## 7. One-shot anti-tamper + App-Link wiring (~5 min after first upload)

After the first AAB upload, Play Console shows the **App Signing certificate SHA-256** under Setup → App integrity → App signing.

The repo ships two helper scripts. Run them in order:

```bash
# 1. Convert the colon-hex Play Console SHA into the base64 form the
#    BuildConfig + SignatureVerifier expects, plus all alternate forms.
bash scripts/compute_signing_sha.sh --hex AB:CD:EF:01:23:...:FF
# Outputs:
#   hex_colon : AB:CD:EF:...   (already what Play gave you)
#   hex_plain : abcdef...      (lowercase, no separators)
#   base64    : K83v...        ← copy this into the GitHub secret

# 2. Update docs/.well-known/assetlinks.json with the same SHA so the
#    https://equipseva.com/pay/return App Link binds to the production APK.
bash scripts/update_assetlinks.sh AB:CD:EF:01:23:...:FF

# 3. Commit + push the assetlinks update.
git add docs/.well-known/assetlinks.json
git commit -m "Bind App Link to production signing SHA-256 (Play Console)"
git push origin main
```

Then in GitHub:
- [ ] **Settings → Secrets and variables → Actions** → add a new repository secret named `EXPECTED_CERT_SHA256` and paste the **base64** value from Step 1.
- [ ] (Re-)trigger the release workflow. `app/build.gradle.kts` reads the secret into BuildConfig; `SignatureVerifier.verify()` flips from report-only to enforce the moment the value is non-blank.
- [ ] Re-upload the release AAB. Play accepts a same-version replacement before publication.

Verification:
- [ ] `curl -sS https://equipseva.com/.well-known/assetlinks.json | python3 -m json.tool` returns the production SHA at the top.
- [ ] On a real device, tap the Razorpay return URL — the OS jumps straight into the App without showing the browser disambiguator.

---

## 8. Submit for review

- [ ] Roll out to **Internal testing** track first. Add yourself + a few testers, smoke-test on real devices.
- [ ] Promote to **Closed testing** with at least 12 testers for 14 days (Google's policy for new accounts since 2024).
- [ ] Promote to **Production** when the closed-testing period is satisfied and all reviews are positive.
- [ ] Play review takes 1–7 days. First-time accounts skew toward 7 days.

---

## 9. Day-zero monitoring

- [ ] Sentry dashboard — set an alert for crash-free-sessions <99.5%.
- [ ] Firebase Crashlytics — confirm crashes are flowing.
- [ ] Razorpay dashboard — set an alert on payment-failure spike.
- [ ] Supabase dashboard — keep an eye on RLS-denied counters (would indicate a misconfigured policy).
- [ ] Set up a `#equipseva-launch` channel and watchful eyes for the first 48 hours.

---

## 10. Items deliberately deferred (post-launch)

These are not v1 blockers; they're tracked in [PENDING.md](../../PENDING.md):

- Admin moderation review queue (separate web project).
- Managed equipment categories / brands table.
- Hindi + Telugu localisation.
- Supplier / manufacturer / logistics persona screens (per PRD §12).
- AI equipment scan (Phase 3).

---

## Source artefacts

- [PRIVACY_POLICY.md](./PRIVACY_POLICY.md) — DPDP-compliant
- [TERMS_OF_SERVICE.md](./TERMS_OF_SERVICE.md) — Indian-law-governed
- [REFUND_POLICY.md](./REFUND_POLICY.md) — RBI + Razorpay compliant
- [DATA_SAFETY.md](./DATA_SAFETY.md) — Play Console answer key
- [STORE_LISTING.md](./STORE_LISTING.md) — title, descriptions, contact, screenshots
- [CONTENT_RATING.md](./CONTENT_RATING.md) — IARC + target-audience answers
