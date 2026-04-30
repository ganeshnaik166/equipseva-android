# Play Store launch assets — v1 candidates

First-cut assets generated 2026-04-30 from the existing brand SVG (`~/Downloads/equipnewlogo.svg`) and the in-app launcher foreground (`app/src/main/res/drawable/ic_launcher_foreground.xml`). Ship-quality enough to submit; a designer can polish post-launch.

## Files

| File | Purpose | Play Console field |
|---|---|---|
| `icon-512x512.png` | High-res app icon master | Store listing → Graphics → App icon |
| `feature-graphic-1024x500.png` | Feature graphic | Store listing → Graphics → Feature graphic |

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

- **8 phone screenshots** — capture from emulator after #214 (round 2 design) merges. Suggested set per the v1 scope (Book Repair + Engineer Jobs only): welcome / role select / hospital home / engineer home / repair-job detail / engineer directory / KYC submitted / chat.
