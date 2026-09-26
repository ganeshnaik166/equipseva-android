# A3-02 cross-account deep-link replay — read-only test plan, 26 September 2026

This is a source review and test plan, not implemented or accepted code. It must follow the A3-01 route-shape policy; both slices edit `DeepLinkRouter.kt`.

## Observed seam

- `DeepLinkRouter.kt:35-43`: singleton `Channel.BUFFERED` stores `OpenRoute(route)` without account or login generation.
- `DeepLinkHost.kt:101-119`: a second buffer can hold the same bare route while the authenticated graph is not ready.
- `MainNavGraph.kt:218-229`: the final consumer navigates without a fresh owner check.

A route received for account A can therefore be delivered after B signs in, or after A signs out and signs in again. A syntax allow-list, RLS, and a route's UUID shape do not resolve that ownership boundary.

## Test-first contract

Use synthetic `FakeAuthRepository`, virtual-time/cancellation-aware tests and no real account or network. Establish failing tests for: A buffered then direct B replacement; A→signed-out→A new login generation; A→B→A; event moved into `DeepLinkHost`'s buffer before B; signed-out and blank IDs; duplicate/email-only session events; `Unknown` including cold-start initial state; late old event; optional FCM recipient mismatch; and a valid same-generation A route that still reaches navigation exactly once. Assert both router emission and final Main admission. Do not pass tests by just draining one of the two buffers.

## Candidate ownership rule

Stamp each accepted external route with an immutable observed login ticket (account ID plus generation) at dispatch, retain it through both buffers, and check it immediately before Main navigation. Retire tickets on observed sign-out, blank ID, account replacement and re-login even to the same ID. An external event with no observed current ticket must fail closed; do not adopt an unbound cold-start route for whichever account signs in next. If recipient-bound FCM payloads are later supported, their binding must be verified independently, not inferred from a route ID. Never suspend the auth collector on network I/O or queue a manual refresh for a future account.

## Integration boundary and acceptance

`AuthRepository.sessionState` is currently a Flow, so an immediate trusted identity snapshot may need a small owned API or upstream session presentation ticket. Validate against current source before choosing an implementation. The session-identity branch separately owns `AppNavGraph`, `MainNavGraph` and `SessionViewModel`; coordinate its merge before touching those files. `SignOutCleanup` and device-token code are shared security lanes; avoid editing them without ownership agreement. Compare older PR1877 tests as hypotheses only, not accepted code.

After A3-01 and session fencing land, freeze the A3-02 diff, run focused RED/GREEN, full applicable unit/lint/debug/unsigned R8, independent critic and QA each ≥9.5 for this scope, hosted CI and physical account-switch navigation. Keep server recipient/object authorization and activity recreation as explicit separate gates.
