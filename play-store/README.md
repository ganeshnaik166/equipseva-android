# EquipSeva Play Store Artifacts

Generated 2026-04-26. All artifacts here are ready for the Google Play submission.

## File map

| File | Purpose |
|------|---------|
| `assetlinks.json` | Digital Asset Links file. Host at `https://equipseva.com/.well-known/assetlinks.json`. |
| `listing-copy.md` | App name, short + full description, categories, tags. Paste into Play Console > Main store listing. |
| `privacy-policy.md` | Full privacy policy. Host as a public page at `https://equipseva.com/privacy`. |
| `content-rating.md` | IARC questionnaire answers. Use when filling Play Console > Content rating. |
| `data-safety.md` | Play Console Data Safety form answers. Paste section by section. |

## How to host `assetlinks.json`

1. Upload `assetlinks.json` to the equipseva.com web root under `.well-known/`.
   Final URL must be exactly:
   `https://equipseva.com/.well-known/assetlinks.json`
2. Serve with `Content-Type: application/json` and HTTP 200.
3. No redirects, no auth, no cookies — Google's verifier follows zero redirects.

### Verify hosting works

```sh
curl -I https://equipseva.com/.well-known/assetlinks.json
# Expect: HTTP/2 200, content-type: application/json
```

Then trigger Android verifier on a connected device (must have the release-signed
build installed):

```sh
adb shell pm verify-app-links --re-verify com.equipseva.app
adb shell pm get-app-links com.equipseva.app
# Expect: equipseva.com -> verified
```

Or use the Statement List Tester:
https://developers.google.com/digital-asset-links/tools/generator

## Keystore fingerprint embedded

`assetlinks.json` contains the SHA-256 from `app/equipseva-upload.jks`
(alias `equipseva-upload`, owner `CN=Ganesh Naik, OU=EquipSeva`):

```
92:B9:05:A8:19:7D:0C:54:E2:91:8B:27:75:DD:9A:F8:C9:A6:F5:13:8F:8C:59:17:77:80:FD:DF:67:A2:D1:C1
```

If you enable Play App Signing, Google will re-sign the bundle with their own key
and you must add a SECOND fingerprint to this JSON (Play Console >
Setup > App integrity > App signing key certificate > SHA-256). Both keys then
sit side-by-side in the array.
