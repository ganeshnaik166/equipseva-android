# `equipseva.com/.well-known/` static host

This directory only exists to serve **one file** — `assetlinks.json` — at
exactly:

```
https://equipseva.com/.well-known/assetlinks.json
```

Android requires this for App Links verification. See
`docs/security/app-links-deployment.md` for the full why + verification
checklist.

## Deploy options (pick one)

### Option A — Vercel (fastest)

```bash
cd well-known
npx vercel --prod
# When prompted, link to a project and the apex domain equipseva.com
# (or a subdomain you alias to apex). vercel.json already pins
# Content-Type: application/json on the well-known path.
```

After deploy, set up the apex domain in the Vercel dashboard pointing
at this project, or have the existing equipseva.com host proxy
`/.well-known/*` to this Vercel deployment.

### Option B — GitHub Pages

```bash
# In a fresh repo equipseva/equipseva-com or similar:
mkdir -p .well-known
cp /Users/ganeshdhanavath/Downloads/equipseva-andriod/well-known/assetlinks.json .well-known/
git add .well-known/assetlinks.json
git commit -m 'Host App Links manifest at /.well-known/assetlinks.json'
git push
# Settings → Pages → Source = main branch, root
# Settings → Pages → Custom domain = equipseva.com
# DNS: CNAME equipseva.com → <username>.github.io (or A records to
# 185.199.108.153, 185.199.109.153, 185.199.110.153, 185.199.111.153).
```

GitHub Pages serves `application/json` for `.json` files automatically.

### Option C — Cloudflare Pages

Same as GitHub Pages, but push to a Cloudflare-connected repo and
attach the `equipseva.com` custom domain in Cloudflare Pages settings.
Cloudflare auto-detects Content-Type from extension.

### Option D — Existing webserver

If you already have a webserver hosting `equipseva.com`, just drop
`assetlinks.json` at `/.well-known/assetlinks.json` on it. Make sure:

- HTTPS only, no redirects (must `200` directly, not 3xx)
- `Content-Type: application/json` (no charset suffix)
- No auth required, no cookies
- File contents are byte-identical to the one in this directory

## Verify after deploy

```bash
curl -I https://equipseva.com/.well-known/assetlinks.json
# expect: HTTP/2 200 + content-type: application/json (no charset)

curl -s "https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https%3A%2F%2Fequipseva.com&relation=delegate_permission%2Fcommon.handle_all_urls" | jq
# expect: statements array with com.equipseva.app + com.equipseva.app.debug

# On a USB-connected device:
adb shell pm verify-app-links --re-verify com.equipseva.app
adb shell pm get-app-links com.equipseva.app
# expect: equipseva.com → verified
```

## After first Play AAB upload

Add the Play App Signing key SHA-256 to `assetlinks.json` (in this
directory AND `docs/security/assetlinks.json`) under the
`com.equipseva.app` target — keep the existing upload-key fingerprint
too. Re-deploy.

See `docs/security/LAUNCH_INFRA.md` for the full one-shot post-upload
runbook.
