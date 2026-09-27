# A10 engineer-status integration — independent QA, 27 September 2026

**9.6/10: bounded local QA pass for observed-login engineer-status isolation.**
I reviewed the clean combined-tree HEAD `1606220557d37f48ba9d1747d2087cc2592ac472`
against accepted `origin/main` `06a4f9f85c82e1834eb74e55dd8f5776c4a36b70`.
The app/test diff changes only `DeepLinkHost.kt` engineer-status handling and adds
`DeepLinkHostEngineerStatusTest.kt`; the remaining diff is a `CURRENT_STATE.md`
scope record. `git diff --check origin/main...HEAD` was clean. The compile-only
test fixture correction is committed at `f3e8727e`; it replaces the unavailable
`RecordingUserPrefs` helper with a self-contained MockK `UserPrefs` double.

The coordinator's targeted JUnit XML for
`com.equipseva.app.navigation.DeepLinkHostEngineerStatusTest` reports **23 tests,
0 failures, 0 errors, 0 skips** on this checkout. The preceding compile attempt
failed because `RecordingUserPrefs` was unavailable; the corrected targeted run
is the evidence used here. I did not run Gradle or use the shared build slot.

| Requested behavior | Source and test evidence |
| --- | --- |
| Signed-out reset and same-account re-login | `DeepLinkHost.kt:73-98` retires the owner and clears status; tests `:136-168` and `:375-390` assert reset, refetch and stale-old-A rejection. |
| Direct A→B and observed A→B→A | Owner generation changes at `DeepLinkHost.kt:82-87`; tests `:170-230` and `:358-373` prove B/final A can publish while old responses cannot. |
| Late noncooperative response and cancellation | Request revision, job cancellation and final ownership check at `DeepLinkHost.kt:100-127`; tests `:214-230`, `:375-409`, `:440-484` include noncooperative and cooperative completions. |
| Duplicate and email-only session events | Same observed UID keeps its owner at `DeepLinkHost.kt:82-83`; tests `:232-243` and `:411-426` cover changed/null email and forced duplicate events without cancelling the pending request. |
| Blank IDs and Unknown | Invalid IDs and Unknown retire the owner at `DeepLinkHost.kt:75-81`; tests `:245-273` and `:428-459` cover null status, no invalid fetch, dropped manual refresh and later fresh sign-in. |
| Failed fetch and manual refresh | `DeepLinkHost.kt:100-140` clears status, keeps the auth collector free of network I/O and snapshots only the current owner; tests `:275-356` and `:486-512` cover failure, retry, no queued future-login refresh, no extra auth subscription and successful fresh requests. |

No mandatory source or test-design gap was found in **this A10 boundary**. The
implementation explicitly cannot distinguish login transitions the auth
repository never emits. It does not close A3-02 buffered deep-link replay,
repository-level identity, server authorization or broader session security.
One separate UX follow-up is `MainNavGraph.kt:260-261`: a null status caused by
loading/offline/Unknown shows “Submit your KYC first”; navigation still fails
closed. That wording is outside this narrow source ownership.

The coordinator's **full exact-tree unit/lint/debug/unsigned-release checks and
hosted CI were pending when this review was written**. Those are separate gates
before main integration. Physical-device/TalkBack behavior, a signed release
and any production deployment were not verified; this is not an app-wide or
release score.
