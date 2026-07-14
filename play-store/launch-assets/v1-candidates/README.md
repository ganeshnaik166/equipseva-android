# Play Store launch assets — v1 candidates

First-cut assets generated 2026-04-30 from the existing brand SVG (`~/Downloads/equipnewlogo.svg`) and the in-app launcher foreground (`app/src/main/res/drawable/ic_launcher_foreground.xml`). Ship-quality enough to submit; a designer can polish post-launch.

## Files

| File | Purpose | Play Console field |
|---|---|---|
| `icon-512x512.png` | High-res app icon master | Store listing → Graphics → App icon |
| `feature-graphic-1024x500.png` | Feature graphic | Store listing → Graphics → Feature graphic |
| `screenshots/01-welcome.png` | Cold-start welcome (logo + tagline + sign-in/create-account CTAs). 1080×2400 portrait. | Store listing → Graphics → Phone screenshots |
| `screenshots/02-signin.png` | Sign-in form (empty, no PII). 1080×2400 portrait. | Store listing → Graphics → Phone screenshots |
| `screenshots/03-role-select.png` | Signup role picker (Hospital admin / Biomedical engineer). 1080×2400. | Phone screenshots |
| `screenshots/04-hospital-home.png` | Hospital dashboard ("What needs fixing today?" + book/bookings cards). 1080×2400. | Phone screenshots |
| `screenshots/05-engineer-home.png` | Engineer dashboard (find work / bids / earnings). 1080×2400. | Phone screenshots |
| `screenshots/06-engineer-directory.png` | Verified-engineer directory (search + filters + engineer cards). 1080×2400. | Phone screenshots |
| `screenshots/07-kyc.png` | Engineer KYC / verification flow (Submitted→Under review→Verified stepper). 1080×2400. | Phone screenshots |

## Specs

- **Icon**: 512×512 PNG, RGBA, ~116 KB. Solid #0B6E4F background per existing brand. EQ glyph in white at 72 % of canvas (centered, with safe-zone padding).
- **Feature graphic**: 1024×500 PNG, RGB, ~88 KB. Same icon (resized to 360×360) on the left, "EquipSeva" wordmark + tagline "Hospital equipment, repaired faster." on the right. Flat brand-green background.

Both are well under Play's 1024 KB per-asset cap.

## Known limitations (cosmetic only)

- Icon background has minor color banding from the SVG → PNG rasterization via macOS `qlmanage`. Not visible at launcher size; if it bothers you at 512 px, regenerate via `rsvg-convert` or Inkscape (cleaner anti-aliasing).
- Feature graphic uses Helvetica for the wordmark (system font); a designer-set custom typeface would feel more premium.

These are non-blockers for v1 submission — Play accepts both as-is.

## Regenerate from source

If the brand SVG changes, regenerate both files:

```bash
# 1. Render icon at 512x512 via macOS QuickLook
mkdir -p /tmp/equipseva-icon
qlmanage -t -s 512 -o /tmp/equipseva-icon ~/Downloads/equipnewlogo.svg

# 2. Normalize + compose feature graphic via Python+PIL
python3 << 'PY'
from PIL import Image, ImageDraw, ImageFont
import os

GREEN = (11, 110, 79, 255)
WHITE = (248, 248, 248, 255)
icon = Image.open('/tmp/equipseva-icon/equipnewlogo.svg.png').convert('RGBA').resize((512, 512), Image.LANCZOS)
icon.save('play-store/launch-assets/v1-candidates/icon-512x512.png', 'PNG')

W, H = 1024, 500
canvas = Image.new('RGB', (W, H), GREEN)
small = icon.resize((360, 360), Image.LANCZOS)
canvas.paste(small, (70, (H - 360) // 2), small)
draw = ImageDraw.Draw(canvas)
font_path = '/System/Library/Fonts/Helvetica.ttc'
draw.text((480, 170), 'EquipSeva', font=ImageFont.truetype(font_path, 96), fill=WHITE)
draw.text((480, 285), 'Hospital equipment, repaired faster.', font=ImageFont.truetype(font_path, 34), fill=(220, 240, 230, 255))
canvas.save('play-store/launch-assets/v1-candidates/feature-graphic-1024x500.png', 'PNG', optimize=True)
PY
```

## Still needed for v1 submission

**Update 2026-07-14 — 7 screenshots now captured** from a signed-in emulator (Android 15 / API 35, AEHD-accelerated) against the live backend, driven headlessly via `adb uiautomator`. Two throwaway test accounts (`eqs.engineer.demo@gmail.com`, `eqs.hospital.demo@gmail.com`) were created through the app to reach the authed screens. This exceeds Play's minimum-of-2 and gives a rich listing.

Two screens from the ideal 8-shot set remain **uncaptured**, blocked by backend/data setup (not app UI):

- **repair-job detail** — hospital "Post new job" → `repair_jobs` INSERT fails for a self-signed-up hospital (org-linkage RLS; cf. root PENDING #60 "test accounts = manual DB inserts today"). Needs a hospital test account linked to a hospital org, or one seeded repair job.
- **chat** — needs a job + engineer bid + hospital accept; the engineer job-feed is gated behind KYC *verification* (admin approval), so an unverified engineer can't bid. Needs one admin-verified engineer + a matched job.

Also note: `06-engineer-directory.png` shows seeded engineers named "Testy"/"Test E2E Engineer" — fine functionally, but reseed with realistic names before final submission. A `07-kyc.png` shows the KYC flow's step 1 (verification stepper); the "submitted" confirmation state couldn't be captured because returning from the OS document picker recreated the activity and reset the multi-step engineer onboarding wizard (observed on the headless emulator).

Freshly-captured copies also live in `../screenshots-emulator/` (original filenames).
