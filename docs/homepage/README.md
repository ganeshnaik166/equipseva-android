# Public homepage build

GitHub Pages publishes `docs/` on `main`. `../index.html` uses `layout: null`
to stand alone without changing the legal pages or account-recovery layout.
Do not restore `docs/index.md`: both would compete for the same output path.

```sh
cd docs/homepage
pnpm install --frozen-lockfile --ignore-scripts
pnpm run build
pnpm run check
pnpm audit
```

The committed `../assets/homepage/scene.js` bundles pinned Three.js and the
original procedural scene. Pages serves the bundle; no build tool or runtime
CDN is required by visitors. `--ignore-scripts` works with the platform esbuild
package selected by this lockfile. Node 22 or newer is recommended.

The logo is the owner's supplied SVG. Space Grotesk and Inter derive from the
repository's `app/src/main/res/font/*_variable.ttf`; SIL OFL notices are shipped
beside them. The WOFF2 subsets include U+0000–00FF, U+2000–206F, U+2190–21FF and
U+2733. Regenerate with fontTools + Brotli using `pyftsubset <original.ttf>
--output-file=<name>.woff2 --flavor=woff2
--unicodes=U+0000-00FF,U+2000-206F,U+2190-21FF,U+2733`.
The Three.js MIT notice is included in the assets directory.

## Browser verification contract

Preview `docs/` on localhost and strip the opening Jekyll front matter from
`index.html` (or use Jekyll). Check 320, 390, 768 and 1440 CSS-pixel widths;
keyboard navigation; readable focus rings; reduced motion; pause/resume;
offscreen and hidden-tab suspension; disabled JS; blocked WebGL; and WebGL
context loss. The original SVG sculpture is the non-WebGL fallback. A WebGL
context loss keeps that fallback until reload. No real accounts are needed.

After Pages deploys, verify HTTPS, current homepage text/assets, mailto contact
actions after Cloudflare transforms, and preserved `/privacy/`, `/terms/`,
`/refunds/`, `/auth/reset.html` and `/.well-known/assetlinks.json` routes.
This homepage advertises the product's direction, explicitly in development;
it does not offer registration, subscriptions or a store download.
