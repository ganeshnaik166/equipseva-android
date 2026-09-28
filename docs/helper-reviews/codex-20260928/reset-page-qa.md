# Hosted reset-page security — independent QA, 28 September 2026

**Historical PR1905 review.** This score does not apply to the later clean
publishable-key branch until that branch receives its own exact-source review.

Reviewed clean branch head `3761e5a8746eec95b9e6e86dd8bc5820005201ee`, page/QA-repair source `a907fe51464cdc6c361366a0db735ab5547a456a`, against incorporated main `5e098defea73e54185d238892eab48bc055d12ca`.

**9.6/10, scoped local pass. No mandatory source/test blocker remains.** The former `b5b4b4ee` review scored **9.4/10 RED** for undersized touch targets and misleading offline verification copy; this final review supersedes that score only for the corrected local candidate.

I reran `pnpm test` (**10/10**), `pnpm run check:bundle` (byte match), JavaScript syntax, and opt-in local Chrome smoke (**1/1**). At 1024×768 and 320×420, both fields measured **48 px**, submit **52 px**, support **135.39×48 px**. The compact page was 320 px wide with no horizontal overflow; the support link remained reachable after scrolling. An invalid marker-only link removed the fragment, kept submit disabled, displayed fixed copy and produced no external Auth request. The synthetic transport-failure test confirms `setSession`/`getUser` errors do not enable submit, trigger `updateUser`, or expose token/provider details. Valid-session, mismatch, duplicate-submit and generic update-failure cases remain in the offline suite.

The workflow covers `docs/auth/**` PR/main changes with pinned tooling and offline checks. The Chrome smoke intentionally needs explicit local Playwright/Chrome paths and is not a hosted gate. The returned local sign-out error can leave an ephemeral in-memory session until page unload; do not claim guaranteed cleanup. Live provider delivery, expiry/replay, deployed CSP/bytes, HTTP `frame-ancestors` and physical accessibility are separate gates. A later test-title wording correction changes no assertion or page behavior.
