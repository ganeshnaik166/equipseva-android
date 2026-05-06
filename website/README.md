# EquipSeva — Marketing Website

Static, multi-page marketing site. Pure HTML + CSS + GSAP via CDN.
No build step. Deploy by serving this folder.

## Pages

- `index.html` — landing
- `features.html` — capability grid
- `how-it-works.html` — 4-step pinned-scroll
- `for-hospitals.html` — hospital admin track
- `for-engineers.html` — biomedical engineer track
- `pricing.html` — v1 free + future pricing
- `about.html` — mission, values, team
- `contact.html` — sales/support form + addresses
- `faq.html` — segmented FAQs
- `blog/index.html` + 3 long-form posts
- `privacy.html`, `terms.html`, `refund.html` — legal
- `404.html` — fallback
- `sitemap.xml`, `robots.txt`

## Stack

- GSAP 3.12 + ScrollTrigger (CDN)
- Lenis 1.1 smooth scroll (CDN)
- Inter + Space Grotesk via Google Fonts
- Zero build step. Open `index.html` in any browser.

## Local preview

```bash
cd website
python3 -m http.server 5173
# open http://localhost:5173
```

## Deploy

Any static host (Vercel, Netlify, GitHub Pages, Cloudflare Pages, S3+CloudFront).
For Vercel:

```bash
vercel deploy
```

Or drop the folder onto Netlify. No env vars required.

## SEO

- Title + description + keywords on every page
- Canonical link, Open Graph, Twitter cards
- JSON-LD: Organization, MobileApplication, FAQPage, HowTo, BlogPosting, BreadcrumbList
- `sitemap.xml` + `robots.txt` at root
- Semantic HTML (`<header>`, `<main>`, `<article>`, `<nav>`, `<footer>`)
- Lazy `defer` script loading; reduced-motion respected
