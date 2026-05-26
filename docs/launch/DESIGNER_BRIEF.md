---
title: Designer brief — EquipSeva Play Store launch
permalink: /designer-brief/
---

# Designer brief — EquipSeva Play Store launch assets

Self-contained handoff for whoever produces the v1 Play Store visual assets. The placeholder pipeline in PRs #980 / #1005 covers what we have right now (programmatic teal/blue gradient mark, Indian-mobile-OK ECG-line social card). This brief specifies what should replace them.

> **Important context (often missed)** — EquipSeva v1 ships as a **service-only** product: repair jobs + AMC contracts + verified biomedical engineers. The parts-marketplace / shopping-cart language in older docs (STORE_LISTING.md) is from an early Phase-1 vision that was retired. Screenshots and copy below reflect the v1 reality.

---

## Brand essentials

| Token | Value |
|---|---|
| Primary brand | **Teal** `#00d3c0` |
| Brand secondary | **Blue** `#0070f3` |
| Brand deep / shadow | `#054a35` (teal-700) |
| Bg dark | `#0b1220` |
| Bg light surface | `#ffffff` |
| Ink 900 / 700 / 500 | `#0b1220` / `#3d4a63` / `#6c7a91` |
| Accent (highlights) | `#00d3c0` at 12% bg, 100% line/text |
| Success | `#0f9d58` |
| Warning | `#f59e0b` |
| Danger | `#dc2626` |
| Type — display | Space Grotesk SemiBold (700) |
| Type — UI body | Inter (400/500/600) |
| Mark glyph | Stylised "EQ" (see existing logo.png for shape baseline) |
| Brand voice | Direct, India-grounded, healthcare-credible. Hindi loanwords OK in body copy ("seva" = service). |

The website's `website/styles.css` already encodes these tokens — open `equipseva.com` for live colour pick.

---

## Deliverables (drop into `website/` and `play-store/launch-assets/`)

### 1. App icon

| | Spec |
|---|---|
| **Master** | 512×512 PNG, 32-bit RGBA, no padding, ≤ 1 MB |
| **Adaptive (Play)** | Foreground 432×432 inside 1024×1024 safe-zone canvas; background can be brand teal flat `#00d3c0` or the teal→blue gradient |
| Mood | Friendly + medical-credible. NOT clinical cold. The current programmatic mark (white "EQ" wordmark on teal/blue rounded square) is a fine baseline |
| Don't | Use stock medical-cross / stethoscope cliché. Don't put fine text inside the icon — illegible at 48dp |

Output files:
- `website/logo.png` (overwrites current placeholder)
- `app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` background swap (only if mark changes) — leave adaptive XML structure intact
- `play-store/launch-assets/icon-512.png`

### 2. Feature graphic (Play store hero)

| | Spec |
|---|---|
| **Size** | 1024×500 PNG, RGB (no alpha), ≤ 1 MB |
| Subject | Bold brand statement + ONE visual anchor. Recommended layouts: |
| Layout A | Left: large EquipSeva wordmark + tagline. Right: stylised illustration of a biomedical engineer + repair tool overlay (vector, not stock photo) |
| Layout B | Centre: the app's home-screen hero in a phone bezel mock, brand-tinted background |
| Don't | Text smaller than 24pt at the displayed scale — Play crops + compresses heavily on small devices |

Tagline options (pick one or refine):
- **"Verified biomedical engineers, on demand across India."**
- **"Repair hospital equipment in days, not weeks."**
- **"Book trusted biomedical engineers. Track every visit."**

Output: `play-store/launch-assets/feature-graphic-1024x500.png`

### 3. Phone screenshots (8–10 frames, v1 service-flow only)

| | Spec |
|---|---|
| **Size** | 1080×1920 (portrait) or 1920×1080 (landscape); pick one and stay consistent |
| **Bezel** | OK to mock in a Pixel 8 / Galaxy S24 frame. NOT required by Play but helps premium feel |
| Captions | Optional 1-line caption per screen at the top — bold sans, ≤ 6 words |
| **Status bar** | Either show a polished status bar (full battery, time 9:41, 5G) or hide it entirely. Don't ship debug-build screenshots with low-battery / dev menus |

#### Recommended order (v1 — service-focused, NOT marketplace)

1. **Hospital home hub** — caption "Find a verified engineer in minutes"
   _UI: role = hospital, "Request service" CTA, recent jobs strip, top-rated engineers carousel._
2. **Request service wizard** — caption "Tell us what broke, get matching engineers"
   _UI: 5-step wizard mid-flow (equipment picker step), map pin visible._
3. **Bids inbox** — caption "Pick the engineer who fits your budget + ETA"
   _UI: stacked bid cards with engineer name, rating, ETA chip, ₹ amount, verified badge._
4. **Live engineer tracking** — caption "Track the engineer on the way"
   _UI: map with engineer pin moving toward hospital pin, status pill "On the way · 14 min"._
5. **Photo proof closeout** — caption "Before / after photos and signed completion"
   _UI: dual-photo grid (broken → fixed), signature box, "Close job" CTA._
6. **AMC contract dashboard** — caption "Plan equipment maintenance year-round"
   _UI: AMC card with monthly visit timeline, next-visit date, escalation contact._
7. **Engineer earnings (engineer role)** — caption "Get paid the moment a job closes"
   _UI: EarningsHeroCard mid-month with ₹ total / paid / pending + Withdraw pill._
8. **Engineer KYC verified state** — caption "Aadhaar + PAN verified, hospitals see ✓"
   _UI: KYC screen post-approval, green StatusBanner "Verified", engineer profile preview._

**Optional 9 + 10 (founder ops, only if pitching multi-role to enterprise):**
9. Notifications inbox with per-category mute + quiet hours.
10. Founder dispute-resolution console (escalated job detail).

Output:
- `play-store/launch-assets/screenshot-01.png` … `screenshot-10.png`

### 4. Social-share Open Graph card

Already shipped in PR #1005 (`website/og.png` — programmatic). Designer-grade replacement should follow the same constraints:

| | Spec |
|---|---|
| **Size** | 1200×630 PNG, ≤ 300 KB (LinkedIn / Twitter render larger versions; pick a master that downsamples cleanly) |
| Content | Brand mark + wordmark + tagline + URL. Three feature chips (KYC-verified, Live tracking, Photo proof) are a nice anchor but optional |
| Test against | https://www.opengraph.xyz/url/https%3A%2F%2Fequipseva.com and Facebook's Sharing Debugger |

Output: `website/og.png` (overwrites current).

### 5. Favicon (already shipped, low priority for redesign)

| | Spec |
|---|---|
| **Size** | Multi-resolution `.ico` containing 16×16, 32×32, 48×48, 64×64 |
| Content | The mark alone (no wordmark — illegible at 16px) |

Output: `website/favicon.ico` (overwrites current).

---

## What the developer needs from you (so wiring is one-shot)

1. **Filenames must match** the existing paths exactly — those are referenced from `<meta>` tags in 16 HTML pages, JSON-LD, sitemap, and Android resources. Renames break things.
2. **PNG only** for raster assets (no WebP for Play store — Play rejects). SVG OK only for the favicon source (we'll rasterise).
3. **No third-party tracking pixels / Google Fonts loaders / etc.** — if you want a font, deliver the font file too (we self-host).
4. **Brand kit** is nice but optional — Figma / Sketch source file at `play-store/launch-assets/design-source/` so future iterations don't start from scratch.

---

## Out of scope for v1 (do NOT design these)

- Splash-screen art — handled by Android 12+ system splash + `Theme.EquipSeva.Splash` (lives in code, not assets).
- In-app empty states — current `EmptyStateView` component is acceptable for v1.
- Marketing landing pages beyond `equipseva.com/` — that's a separate web project.
- "Founder console" rebrand — internal tool, doesn't ship to Play.

---

## Acceptance checklist

When you're done, the developer will check:

- [ ] All deliverables are under the file paths listed above
- [ ] Each PNG opens cleanly in Preview.app and reports the correct dimensions
- [ ] [Google Rich Results Test](https://search.google.com/test/rich-results) on `equipseva.com/` shows no `Organization.logo` errors
- [ ] [Facebook Sharing Debugger](https://developers.facebook.com/tools/debug/) on `equipseva.com/` shows the new `og.png`
- [ ] Play Console's icon preview at 48dp is still legible (no fine text inside)
- [ ] Feature graphic at the small 320×156 thumbnail Play uses on phone is still readable
- [ ] All 8+ screenshots are from a debug build with **no developer mode UI** visible

Ping the developer (or me) when assets land; me'll wire + ship in one PR.
