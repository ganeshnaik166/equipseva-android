# Static password-reset page

GitHub Pages serves `reset.html`, `reset.css` and the committed `reset.js`
directly from this directory. The JavaScript is bundled from pinned source
and dependencies; the live page must never load a runtime CDN module.

From `docs/auth/`, with Node 24 and pnpm 11.25.0:

```sh
pnpm install --frozen-lockfile
pnpm run build
pnpm run check:bundle
pnpm test
```

Commit the regenerated `reset.js` whenever source or lockfile changes. The
focused `reset-page` workflow repeats the frozen install, bundle comparison
and offline tests on pull requests that change this directory.

The page accepts only an implicit-flow `type=recovery` fragment containing
both token fields. It removes the fragment from browser history before creating
the reset-only Supabase client, keeps the session in memory, confirms the user
with Auth, and enables the form only after that check. It attempts sign-out
with the explicit **local** scope after a successful password update. Synthetic tests
do not prove live provider delivery or expiry behavior; verify those with a
disposable account during the separate rollout gate.

The CSP is a meta tag because the current Pages response has no configurable
per-page CSP header. A meta policy cannot enforce `frame-ancestors`; add that
directive as an HTTP header if hosting control changes. The page also sets a
`no-referrer` meta policy. Review [third-party notices](THIRD_PARTY_NOTICES.md)
when updating the pinned bundle.
