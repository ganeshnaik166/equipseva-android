# Independent critic: final local A2/A10 and separate Welcome slice

Reviewed 2026-09-12 by the independent critic agent. **Critic disposition: the two bounded local slices pass, separately: A2/A10 9.62/10; Welcome 9.59/10.** Every applicable critical dimension reaches 9.5. This is one reviewer's disposition; independent QA and coordinator integration remain separate. It is not whole-app, whole-authentication, M1/M2/M4, device, provider or release acceptance.

## Exact scope and provenance

The accepted source is the 768-file set in `verification.json`, captured before the final combined bar and after its recovery, with **zero changed, added or missing files** independently verified. Base checkpoint: `e58c48c2774a77aa0e725f1945da4e48a0fd5873`; that base commit alone does not contain the final uncommitted implementation. Delivery commit was not yet assigned when this review was written. The coordinator must bind the delivered commit to these source hashes.

Key SHA-256 hashes:

| Source | SHA-256 |
| --- | --- |
| `features/auth/RoleSelectScreen.kt` | `a4e0ebcf0b57b643528cd821d72fd4d8baa3f4c52021728c1502cc8180d7d2ed` |
| `features/auth/WelcomeScreen.kt` | `8d84f63ce2fea9db21e07db0910c91df3357aa2286bd4b11cdf716741ddcfca0` |
| `navigation/DeepLinkHost.kt` | `9da63ef7ee20dffe60bf9639eebe7e29ccbf4ee532da325e5655e9fe3012eb20` |

Paths above are beneath `app/src/main/kotlin/com/equipseva/app/`. Full production/test/resource/configuration hashes, commands, logs, XML and image provenance are in `verification.json`. Local evidence root is `C:/Users/lokes/Documents/Codex/2026-09-07/im/work/verification/auth-integration-20260912/`.

This reviewer read the contracts, implementation, test scheduling/oracles, actual Native Canvas captures, contrast/layout measurements, preserved failures and final outputs. The critic neither implemented these fixes nor ran Gradle. Only this report was edited. Synthetic root tests use the actual production routing host with inert destination slots; they are not complete destination or device tests.

## Closed findings and retained failure evidence

1. **A10 observer lag:** final `DeepLinkHost.kt:104-155` checks the request owner/revision before and after an immediate current-auth probe at both network admission and publication. The probe accepts only a completed, noncancelled first emission; delayed/non-replaying work is cancelled and fails closed. A cancelled parent cannot admit a later request. Full emission traces now cover raw B, SignedOut and Unknown overtaking the full observer, not merely final StateFlow values.
2. **A10 wrong row owner:** line 111 rejects a fetched engineer row unless `Engineer.userId` equals the captured owner. Foreign, empty and whitespace row owners remain null; valid subsequent requests still succeed. The source check supplements, and does not replace, repository/server ownership.
3. **A2 primary-action contrast:** explicit foreground/background pairs at `RoleSelectScreen.kt:188-193` produce actual enabled white/green contrast **6.2546:1**, and disabled/Saving ink/Paper3 contrast **5.5605:1**, in both themes. Save, Try again and Check again have rendered evidence.
4. **A2 radio contrast:** the original dark unselected radio was **1.6146:1**; light Saving also failed at **2.399:1**. The coordinator explicitly extended the contract before adding two red tests and the minimal color fix at lines 302-307. All 16 final cropped combinations pass, minimum **5.5811:1**; unselected rings reach **10.4049:1**. Selected dots and existing accessible selection semantics are retained in disabled states.

The initial integration red run is preserved: **63 tests, 15 failures** (RoleSelect 11/3; A10 35/12; route regressions 17/0). The focused 189-test green run omitted two suites because of incorrect package selectors; this was disclosed rather than counted as coverage. Both suites execute in later checks and the final full suite. The expanded radio run and all original contrast failures remain available; cumulative historical measurements are not presented as an all-green file.

A10 explicitly retires its owner on **Unknown**, resets status to null and cancels pending work. SignedOut and blank IDs also clear it. Same-login duplicate/email-only events do not refetch; observed A-B-A and sign-out/relogin produce fresh generations. Latest refresh wins; network I/O never blocks the full auth collector. A manual call does not wait for a future account. Failed/missing/foreign rows and unreadable live auth remain null, and valid fresh requests work. The 35-case final suite also covers noncooperative completion, mapped StateFlow, suspended probes and manual refresh after VM clear.

## Welcome review, separately scoped

The signed-out Welcome component has a scrolling, width-bounded layout, an accessible brand heading, decorative logo, and informative hospital/engineer cards. Those cards do not choose a role. Sign in and Create account are independent named actions with at least 52dp height; Terms and Privacy are independent 48dp actions. Existing public callbacks and the exact `https://equipseva.com/terms` and `/privacy` destinations are preserved. No auth repository, role policy, network request or dependency was introduced. Copy removes the former on-time-payment guarantee.

The reviewer inspected the light/dark rendering and EN/HI/TE initial/actions viewport captures at 320dp portrait and 640dp short landscape with 2x text. Each text item and full action is also checked after scrolling; screenshots are viewports, not a claim that all content fits on one screen. Some initial viewports start partway down: their neutral names are intentional, and brand reachability is separately tested. The 36 retained PNGs from the previously reviewed capture set match the final files byte-for-byte; six obsolete `top`-named historical captures are absent from the final set. These are Robolectric Native Canvas images, not physical-device screenshots. Minimum actual rendered text contrast is **8.3127:1** in both themes.

Test-first history is preserved: the callback-only extraction produced **11/11 runtime failures** after the DpRect test compile correction. The first implementation produced **11/6** on `didOverflowWidth`; diagnostic evidence showed a fully fitting brand (measured width 171, paragraph width 272, intrinsic 170.5, rightmost glyph edge 169.81888). I independently agreed to replace that aggregate flag with line edges within the **actual measured text width**, plus semantic viewport bounds, while retaining full-character, no-ellipsis and all height checks. This was supported oracle repair, not tolerance widening. The next **11/6** exposed centered action paragraph/measurement mismatch. Production action and legal Text now fill their available width (`WelcomeScreen.kt:219,243`), retaining the strict oracle and the user's font scale. Final focused and full execution: **11/0/0/0**. No failed case was ignored or relabelled as accepted.

## Final execution and configuration limits

Final command:

```text
.\gradlew.bat :app:testDebugUnitTest :app:lintDebug :app:assembleDebug :app:assembleRelease --max-workers=2 --no-configuration-cache --no-daemon
```

Environment: Microsoft JDK 17.0.19.10, local Windows Android SDK, existing `PRECHECK_LOOSE=1` local compile mode. The first final combined attempt freshly executed **3,110 tests in 355 suites, zero failures/errors/skips** and completed lint, then failed at `preReleaseCheck` because bash was absent from process PATH. The installed Git Bash was added to process PATH and the same-source command completed **exit 0, BUILD SUCCESSFUL in 4m 1s**, 19 executed/115 up-to-date tasks. Unit/lint outputs were reused on recovery; the report does not claim 3,110 tests executed twice. Lint is **0 errors, 82 warnings, 2 hints**, not a warning-free result. An earlier intermediate run failed lint on an escaped Windows SDK path in ignored `local.properties`; that environment repair and failure also remain recorded.

The critic independently parsed `first-combined-xml`: all 3,110 tests pass, including RootSessionHost **23**, RoleSelect UI **13**, A10 **35**, Welcome **11**, TabRoutesForRole **8**, and SessionRecoveryScreen UI **2**. Final before/after source manifests match across all 768 files.

Strict release configuration **still fails** its missing-keystore guard. The loose precheck reports missing `EXPECTED_CERT_SHA256` and release keystore, while its public assetlinks check passes. No guard was edited or suppressed for this change. The resulting artifact is `app-release-unsigned.apk`; actual apksigner inspection returns **DOES NOT VERIFY / Missing META-INF/MANIFEST.MF**. Despite old script comments about debug signing, the inspected artifact is unsigned. R8 assembly is local compilation/shrinking evidence only, not production signing, a shipped release or proof of server/provider behavior.

## Independent critic scores

Scores apply only to the bounded local contracts above. Non-applicable payment writes, full provider authentication, server policy and release deployment are excluded with reasons; they are not awarded passing credit. Native device/TalkBack and participant validation remain explicit later gates under the frozen contracts. No missing mandatory local test is averaged away.

| Renewal-plan dimension | Weight | A2/A10 | Welcome | Evidence and limitation |
| --- | ---: | ---: | ---: | --- |
| Task correctness and completion | 25 | 9.7 | 9.6 | Actual root guards and 35-case owned status contract; Welcome callbacks and 11-case component contract. Destination/provider behavior remains separate. |
| Security and privacy | 25 | 9.6 | 9.6 | Stale-owner, blank/foreign-row and callback negatives; Welcome adds no credentials, persistence, auth policy or dynamic URL. No global security certification. |
| Resilience, retained work and money correctness | 20 | 9.6 | 9.5 | Observed account/generation recovery and cancelled/late work, preserved root drafts; Welcome scrolling and callback separation. Money and evidence mutation are not performed in Welcome. |
| Usability, accessibility and localization | 15 | 9.6 | 9.6 | Measured text/indicator contrast, semantics, large text, EN/HI/TE and action reachability. Native assistive technology and fluent-speaker acceptance remain open. |
| Visual consistency | 10 | 9.6 | 9.7 | Explicit consistent color pairs and readable radio states; coherent green Welcome hierarchy, flexible controls and inspected viewport captures. |
| Performance and operations | 5 | 9.5 | 9.6 | Auth collection never awaits network; cancelled immediate probes; dependency-free bounded component UI; full local build evidence. No device frame-time or production operations claim. |
| **Weighted critic total** | **100** | **9.62** | **9.59** | **Local scoped pass only.** |

The A2 contract's additional review dimensions also pass independently: routing correctness **9.7**, owner/generation isolation **9.6**, callback authorization **9.6**, lifecycle/recovery continuity **9.6**, focused regression **9.6**, evidence quality **9.6**. R01-R13 are supported by the reviewed final production-host/adapter tests, lifetime and held-frame barriers, final A1 regression execution and immutable evidence. Unknown/admin/deferred roles use the supported-role chooser per the later explicit contract freeze; none gains main merely from an unsupported role. The earlier proposed generic recovery-slot language is not substituted for that final contract.

## Open boundaries, not hidden by the scores

- A3 exported/raw route admission and buffered cross-account event replay remain unaccepted. The 17 passing dispatch tests and separately saved WIP `e58c48c2` do not close A3.
- A4/A12 global sign-out cleanup, token revocation, opaque preference/mutation writers and repository credential identity remain separate; A7 signup-role carryover remains open.
- Entirely unobserved same-ID login boundaries cannot be reconstructed by A10. Its immediate-only live-auth probe guarantee is specific to that implementation, not every auth consumer. RoleSelect's own Flow reads and deeper repository mutations do not acquire a new global guarantee here.
- `engineerStatus` influences Jobs/KYC navigation and is not server authorization. There is no production post-KYC `refreshEngineerStatus` caller; API tests do not certify that wiring. Existing `filterNotNull()` restoration waits and raw event delivery are outside this change.
- Actual provider startup, native Back/IME/insets, process/activity restoration, real destinations, keyboard/TalkBack order and announcements, fluent Hindi/Telugu review, hospital/engineer participant tasks, Storage/FCM/direct server authorization, signed device release and whole-code audit remain unassessed.

The full program must resolve its outstanding security and release gates before whole-journey or release acceptance. These scores approve the tested corrections and reversible Welcome component, not the outstanding program.

---

## Historical initial review — preserved, superseded by the final local disposition above

### Independent critic: initial A2 + A10 integration candidate

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
