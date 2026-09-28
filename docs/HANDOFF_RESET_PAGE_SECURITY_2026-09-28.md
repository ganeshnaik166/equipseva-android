# Hosted reset-page security handoff — 28 September 2026

## Ownership and exact state

Isolated checkout: `work/equipseva-reset-page-security-20260928`, branch
`codex/reset-page-security-20260928`. It began at fetched main
`427aa8d03ca8d7af795aa2083baac5ea0ce504c4`, froze page/CI source at
**`3ad3549fc213c38db58317d6b103508b175495db`**, then merged fetched main
`5e098defea73e54185d238892eab48bc055d12ca` (including Android reset
receipt PR1903 and continuity PR1904). This branch owns `docs/auth/**`,
`.github/workflows/reset-page.yml`, and the linked continuity records only.
It did not edit the Android auth UI/repository, SQL, shared Gradle slot, other
worktrees, or production. No reset-page PR, main merge, or deployment is
claimed here. QA rated the former branch head `b5b4b4ee` **9.4/10, RED** for
accessibility and verification guidance. The subsequent test-first repair is
source commit **`a907fe51`**; fresh independent critic and QA reviews of this
source are pending.

## Trigger and resulting behavior

Read-only inspection of live `https://equipseva.com/auth/reset` returned HTTP
200, the mutable `https://esm.sh/@supabase/supabase-js@2` import, and no CSP
header. The old page accepted `#type=recovery` without tokens or a token
without recovery type; the default browser client could reuse a prior saved
session and call `updateUser` for that account. It also displayed raw fragment
`error_description` and retained the fragment in the address bar.

The candidate checks for one exact `type=recovery` marker plus both token
fields, removes the entire fragment with `history.replaceState`, and creates
a reset-only Supabase client with `persistSession:false`,
`detectSessionInUrl:false`, and `autoRefreshToken:false`. The submit button is
disabled in HTML and remains disabled until explicit `setSession` succeeds and
`getUser` confirms the same user. Invalid fragments receive fixed copy; any
link-session verification failure gives neutral guidance to check the
connection, reopen the email link, or request a new email. It does not echo
provider details or restore the fragment. A successful update attempts
`signOut({ scope: 'local' })`; bare `signOut()` would affect other sessions.
The page keeps the original form and visual theme, with external CSS and an
announced status region. Password fields have at least 48 CSS px height, the
primary action at least 52, and the support email link at least 48 by 48.

`reset.js` is self-hosted and built with exact `@supabase/supabase-js@2.108.1`
and `esbuild@0.25.0` from `pnpm-lock.yaml`; the committed bundle is compared
byte-for-byte in local and hosted checks. The CSP meta tag precedes all
resources and permits script/style/images only from self and connections only
to the exact Supabase project host. `form-action`, frames, workers, objects and
base URLs are denied; a `no-referrer` meta policy is present. The pinned SDK
contains an optional bare `@opentelemetry/api` dynamic import in unrelated
code; it is not a cross-origin URL. Chrome's synthetic auth flow made no
other-origin requests, and the CSP blocked an injected CDN script.

## Verification at frozen page source and merged main

- Test-first `node --test docs/auth/test/reset-static.test.mjs` on the old page:
  **3 tests / 3 expected failures** for missing CSP, inline assets, and no
  local bundle. The flow suite initially failed because the controller module
  did not yet exist.
- `pnpm install --frozen-lockfile --offline` in `docs/auth/`: exit **0** after
  the initial registry resolution; only pinned `esbuild@0.25.0` is approved
  for an install script. `pnpm run build` and `pnpm run check:bundle`: exit **0**.
- `pnpm test` at code commit `3ad3549f` and again after the main merge:
  **9 tests / 0 failures**. Cases cover exact fragment shape and cleanup,
  stale browser storage with invalid link, rejected/mismatched sessions,
  update success/failure, and duplicate submit. `node --check` passed for all
  three local source/build modules.
- `pnpm audit --prod --audit-level high`: exit **0**, no known vulnerabilities
  reported by the registry at this check. `pnpm licenses list --json` showed
  MIT runtime packages and 0BSD `tslib`; [bundle notices](auth/THIRD_PARTY_NOTICES.md)
  retain their notices. Lockfile versions and integrity hashes were inspected.
- Local Chrome/Playwright with a loopback file server, preloaded synthetic
  localStorage, and intercepted fake Supabase endpoints: invalid marker-only
  link stayed disabled and made **0** Auth calls; a synthetic valid link made
  two GET user calls, one PUT user, and one local logout, then showed success.
  No other-origin requests occurred. A separate injected `esm.sh` script
  raised `script-src-elem` violation with **0** outbound requests. No real
  account, provider, or recovery token was used.

## QA 9.4 follow-up at source `a907fe51`

QA measured 43.2 px password fields, a 45.6 px primary action and a 16 px
support-link target on former head `b5b4b4ee`. It also found that a verification
transport/offline failure showed “invalid or expired” after the fragment had
been cleared. These were mandatory findings; the **9.4/10 result is not
acceptance**. A new Chrome measurement check and synthetic transport test were
RED before implementation: local Chrome measured 43/43 px fields, 45 px
primary action and 16 px support height, and the flow test received the old
invalid/expired message instead of connection guidance.

The repair sets minimum target sizes in `reset.css` and gives verification
failure neutral next steps. It continues to remove the whole fragment and
keeps submit disabled if `setSession` or `getUser` fails. A user can reopen the
link from the reset email after checking connectivity, or request a new email
if that fails; the page never restores token-bearing URLs or displays provider
error text. This does not distinguish network failure from expiry at the
provider, so it does not claim provider validity or an in-page retry.

- `pnpm install --frozen-lockfile --offline`, `pnpm run build`,
  `pnpm run check:bundle`, and `node --check src/reset-page.mjs`: exit **0**.
  `pnpm test`: **10/10 GREEN**, including unchanged exact-fragment,
  non-persisted-session, CSP, duplicate-submit, and bundle assertions.
- Optional local `node --test test/browser-targets.smoke.mjs`: **1/1 GREEN**
  using Playwright **1.62.1** and Chrome **153.0.8010.50**. It requires
  `EQUIPSEVA_PLAYWRIGHT_PATH` pointing to the installed Playwright module and
  `EQUIPSEVA_CHROME_PATH` pointing to the Chrome executable; the test does not
  silently use a global installation or download a browser. At 1024×768 and
  320×420, both fields measured **48 px**, primary action **52 px**, support
  link **135.39×48 px**. At 320×420, card top was **24 px**, page height
  **655 px**, support link reachable after scrolling, horizontal overflow
  **0**, external requests **0**. This smoke is separate from offline CI
  because its browser runtime is not declared as a project dependency.
- `pnpm audit --prod --audit-level high`: exit **0**, no known vulnerabilities
  at this check. Tests used only synthetic fragments and fake or intercepted
  responses; no real account or provider call was asserted as successful.

To repeat the optional smoke on this Windows host from `docs/auth/`, set the
explicit local runtime paths and run:

```powershell
$env:EQUIPSEVA_PLAYWRIGHT_PATH='C:/Users/lokes/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright'
$env:EQUIPSEVA_CHROME_PATH='C:/Program Files/Google/Chrome/Application/chrome.exe'
node --test test/browser-targets.smoke.mjs
```

## Remaining gates and merge points

The local browser and Node checks do not prove actual recovery email delivery,
expiry, replay resistance at the provider, production CSP deployment, or
physical-device behavior. GitHub Pages currently supplies no CSP response
header, and a meta CSP cannot enforce `frame-ancestors`; that requires a host
or edge HTTP header. The live page remains the old version until a reviewed
main merge and Pages publication, with the observed CDN cache potentially
delaying byte parity. Verify the live HTML, CSS, JS and effective CSP after
publication; use a disposable account for provider validation. The generated
bundle is pinned and self-hosted, but later dependency upgrades require a
fresh license/security review and regenerated asset.

The only merge conflict with PR1903/PR1904 was the top of
`docs/CURRENT_STATE.md`; both records were preserved. No reset-page source
overlap occurred. The `reset-page` workflow covers docs-only PRs, where the
Android and web workflows are not expected to run. Next: obtain separate
critic and QA review of source `a907fe51` and its continuity diff/evidence at
or above the repository's 9.5 gate, address findings, then have the coordinator
open and validate the PR. Keep main integration, hosted deployment and release
acceptance separate.

SDK behavior references: [setSession](https://supabase.com/docs/reference/javascript/auth-setsession),
[updateUser](https://supabase.com/docs/reference/javascript/auth-updateuser),
[CSP meta limitation](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Content-Security-Policy/frame-ancestors).
