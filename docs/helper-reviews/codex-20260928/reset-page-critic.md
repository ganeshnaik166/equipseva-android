# Hosted reset-page security — independent critic, 28 September 2026

**Historical PR1905 review.** This score does not apply to the later clean
publishable-key branch until that branch receives its own exact-source review.

Reviewed clean branch head `3761e5a8746eec95b9e6e86dd8bc5820005201ee`, page/QA-repair source `a907fe51464cdc6c361366a0db735ab5547a456a`, against incorporated main `5e098defea73e54185d238892eab48bc055d12ca`.

**9.6/10 for the bounded page source, offline tests and optional local browser smoke. No mandatory blocker in this scope.** This does not accept the deployed page, real provider flow, device accessibility or release.

I independently reran `pnpm test` (**10/10**), `pnpm run check:bundle` (byte match), JavaScript syntax checks, `git diff --check`, and the opt-in Chrome smoke (**1/1**). The browser measured both fields at **48 px**, the primary action at **52 px**, and the support link at **135.39×48 px** at desktop and 320×420. The compact layout had no horizontal overflow and kept support reachable. The invalid-link browser path made no external requests. The repair gives fixed connection/reopen/request-new guidance when verification fails, while submit remains disabled and the URL fragment stays cleared.

The page loads a pinned self-hosted bundle under an early restrictive meta CSP; it rejects incomplete recovery fragments, uses a non-persistent reset-only client, and checks the server-confirmed user before enabling password update. The new `docs/auth/**` workflow runs the pinned install, bundle comparison and offline tests on PRs and main pushes. Optional Chrome smoke is documented separately because it needs local browser paths.

Residuals: `reset-page.mjs` ignores a returned error from `signOut({ scope: 'local' })`, so in-memory cleanup after success is attempted, not guaranteed; the completed form remains disabled and nothing is persisted. A meta CSP cannot enforce `frame-ancestors`. Real provider expiry/replay and delivery, hosted checks, deployed bytes/cache/CSP and physical accessibility remain open. A test title that implied guaranteed session closure was subsequently corrected to say “attempts local sign-out”; assertions and page code were unchanged by that wording edit.
