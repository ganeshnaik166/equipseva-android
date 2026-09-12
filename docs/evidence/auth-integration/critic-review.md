# Independent critic: A2 + A10 integration candidate

Status: **unaccepted; final verification and fixes pending**. Reviewed 2026-09-11 in `C:/Users/lokes/Documents/Codex/2026-09-07/im/work/equipseva-auth-integration-20260911`, branch `codex/auth-integration-20260911`, initial candidate HEAD `8749ff71`.

This critic did not modify production/tests, run Gradle, merge, or commit. Only this report is writable. Read the A2 handoff, prior critic/QA contract, GPT-5.3 helper handoff, and Claude continuation handoff. Relevant memory lookup returned no matches.

## Actionable findings sent for correction

1. **A10 ordinary auth-observer lag (must fix).** `DeepLinkHost.kt:106-121` checks only locally observed owner/request state. Queue completion of A's request before the auth observer, publish upstream B/Unknown/SignedOut, then drain: A can emit Verified before the queued observer clears it. The original 23-test suite processes the auth transition before releasing stale work and inspects final `.value`, so it misses this transient publication. Manual refresh can likewise enqueue an A fetch before the source changes and admit it before the observer runs. Require live-auth admission/publication checks and full emission traces. This is distinguishable from an entire same-ID identity boundary lost upstream. Root accepted the finding for a test-first correction; critic has not executed the proposed reproducer.
2. **A10 foreign engineer row (must fix).** `fetchByUserId(A)` returning a row whose `userId` is B is accepted as A's status. Check the returned row owner before extracting its verification status, remain null on mismatch, and prove a fresh correct-owner retry succeeds. This is a defensive boundary against stale/misrouted repository data, not a claim that the current server normally returns the wrong row.
3. **A2 dark primary-action contrast (known blocker).** The inherited dark-theme foreground on a fixed green button was previously measured at 2.378:1. Root owns the minimal color-pair fix and actual light/dark rendering tests. Enabled, retry, saved-check, disabled and saving states must have honest rendered evidence before UI acceptance.

The A10 helper test asserting that manual refresh never creates another auth subscription encodes one implementation choice. The mandatory behavior is to avoid waiting for a future account and to reject stale-owner work. Any replacement test must preserve that safety contract, especially a non-replaying auth source with no first emission.

## Existing evidence, not final integration acceptance

Independently read helper `a10-targeted.xml`: 23 tests, zero failures/errors/skips; its log ends BUILD SUCCESSFUL in 51s. The helper manifest records 3,067 full tests before eight further mapper cases, with a later 22-case mapper run. Do not report 3,075 as that historical full run. Strict release was blocked by the missing-keystore guard; no release bypass or signed-release acceptance follows.

The saved A2 manifest reports 3,030 tests in 351 suites, lint/debug/loose-release assembly success, and explicitly leaves dark contrast unaccepted. Those results supersede the old critic draft's full-bar-pending statement only for the old checkpoint. Current integration changes require their own exact-source verification. Raw filesystem hashes may change with checkout line endings; candidate provenance and final hashes must be recorded explicitly.

Static A10 strengths: all auth states are observed without awaiting engineer I/O; Unknown explicitly retires its owner; observed A/B/A and sign-out/relogin create fresh ownership; latest request wins; cancellation is propagated and checked after non-cooperative work; same-login duplicate/email updates do not refetch; failures/missing rows remain null and fresh retries work. These strengths do not close the two findings above.

A2's prior owned atomic presentation, root render guard, explicit NeedsRole/unsupported-role rejection, callback lease checks, Unknown retention, repository invalidations, entry disposal and recovery protections remain the reviewed baseline. Root is preparing actual contrast tests using resolved text color plus drawn opaque button pixels and matching glyph pixels, which is stronger than testing copied color tokens. Exact compiled tests/captures are still pending review.

## Scope limits and ratings

Security, code quality and critic ratings for final A2/A10 are **unassessed** until required negative regressions, fixes and exact-source verification are available. Missing evidence is not rounded up to 9.5. No overall app/authentication/release score is assigned.

`engineerStatus` influences the Jobs-tab and KYC-restore navigation decisions; it is not server authorization and should not be described as purely cosmetic. No production caller currently invokes `refreshEngineerStatus`; post-KYC refresh wiring is not certified by the VM API tests. Existing restore waiting on `filterNotNull()` and raw event forwarding remain outside this A10 logic slice.

Open boundaries: A3 raw/exported routes and buffered cross-account replay; A4 opaque preference/mutation writers, HomeHub data ownership and repository credential identity; A7 signup-role carryover; A12 already-started global cleanup/token revocation/sign-out internals. Entirely unobservable same-ID ABA remains open. Device/provider startup, full real screens, process/activity restoration, native Back/IME/insets, TalkBack, native locale review, Storage/FCM integration and signed release remain unassessed. Local simulated tests and loose release assembly cannot close those gates.
