# A2 independent security and navigation critic review

Reviewed 2026-09-11 by auth_a1_redteam against the shared checkout rooted at `C:/Users/lokes/Documents/Codex/2026-09-07/im/work/equipseva-android`, starting commit `64107db7`.

UNACCEPTED: root subsequently identified a dark-theme RoleSelect button contrast issue. Its fixed green container inherits a dark-theme content color; root reports measured contrast 2.378:1, with explicit white proposed at 6.255:1. These contrast values are root-provided, not independently measured in this report. The UI owner is preparing the fix and dark regression. This remains an acceptance blocker; final UI scoring and source hashes must be updated after the fix. No additional security/navigation must-fix was found by this critic. The scores below are conditional: accept only after the full verification bar succeeds on the final hashes below. At report creation, `../verification/auth-a2-full-01.log` was still running. No product/test edits, Gradle executions, or commits were performed by this critic.

## Scope and findings

Reviewed the actual root policy, render-time admission, AppNavGraph's single SessionViewModel adapter, AuthNavGraph and legacy phone redirect, MainNavGraph role dispatch, HomeHub role display, SignUp completion callbacks, SessionPresentation/SessionViewModel, repository invalidation signal, and RoleSelect save/effect/UI ownership. Reviewed the independent QA routing contract and adversarial test scheduling, including the final pending-Back assertions and test parser loader guard.

Concrete issues identified during this review and now fixed:

- A late global role notification could destroy B's form. Identity-free notifications now retain the validated current gate while requesting an owned background fetch; owner-bound save callbacks invalidate their own gate.
- Dropping the invalidation collector's first emission could lose a notification raised after bootstrap began. A pre-init revision baseline and an immediate-dispatcher regression now cover this interval.
- Captured A callbacks could address the newer VM owner before Compose rendered B. Callbacks carry the originating SessionOwner; the VM checks its actual current owner again.
- Raw Unknown could arrive before the auth observer and leave UI refresh/sign-out armed for later. UI admission reads one raw auth emission, rejects Unknown immediately, and checks ownership after that read.
- A completed sign-out job could allow repeated cleanup before SignedOut arrived. The signingOut guard covers that completed-job interval; failure and cancellation release progress for deliberate retry.
- The legacy signed-out phone-onboarding route could instantiate mandatory authenticated setup. Its registered route now only redirects to sign-in and clears earlier auth children.
- Sign-out progress previously looked like a failed profile load. Localized progress now disables retry/exit appropriately.
- Config.NONE did not isolate the real resource APK. The test-only parser and minimal text manifest now remove startup components before installation, with mandatory isolation checks before each A2 UI activity.

The root admits only explicit supported hospital/engineer roles. NeedsRole, blank, unknown, admin and deferred roles cannot fall into a privileged role surface. Owner/generation/role changes retire the previous entry, ViewModelStore and nested draft. Same-login Unknown retains the entry invisibly and blocks input, focus, Back and callbacks. Role/profile completion can request server validation but cannot directly navigate to Main. RoleSelect uses add_role without preference writes and checks save ownership at result and effect delivery.

## Evidence and oracle assessment

Independently recounted `../verification/auth-a2-targeted-04-results`: 138 tests, 0 failures, 0 errors, 0 skips. `../verification/auth-a2-targeted-04.log` ends BUILD SUCCESSFUL in 35s. Breakdown: Session identity 56; root host 23; root destination 8; tab routes 8; RoleSelect VM 23; RoleSelect state 4; RoleSelect UI 7; recovery UI 2; repository invalidation 3; recording preference fixtures 4. Prior Run02's 137/1 harness failure is preserved and is not represented as a successful run.

The focused tests exercise the production root host with inert slots, actual nested navigation, saved draft state, entry-owned sentinel ViewModels and disposal history. They do not substitute a test routing algorithm. Held-frame tests explicitly prove the VM has advanced while A's old composition remains; callbacks are then invoked against that gap. The raw-Unknown test separately queues actions ahead of the observer. The invalidation-startup test raises the notification inside the first immediate bootstrap, requires two fetches, and rejects the non-cooperative old result. Sign-out tests cover in-flight duplicates, success before SignedOut, failure/cancellation retry, and old cleanup completion after replacement. Existing A1 ownership/revision/preference-race checks remain included.

The signup cancellation test is an actual root-entry lifetime test with a suspended sentinel continuation. It proves cancellation plus a usable role-confirmation fallback; it does not execute the real signup SDK or prove selected-role carryover. The repository tests execute the real repository/SDK with MockEngine; HTTP success stubs do not establish live database privileges.

All nine current PNGs under `app/build/outputs/auth-a2-ui` were visually reviewed: English selected/error states, and Hindi/Telugu narrow 2x text top, hospital-card and bottom states. No card/text-layout defect was found. The corrected final Telugu capture shows the complete sign-out action and explanation. The test now checks full exit bounds and invokes it after scrolling to the end; an earlier partial-visibility capture was not accepted as that evidence. All nine captures are light-theme evidence; the newly identified dark button contrast issue still needs its own corrected capture and test. These are Robolectric Canvas captures, not device screenshots or native accessibility/localization validation.

The final QA-only pending-Back assertions and nullable loader guard postdate Run04. They are statically reviewed but require the running final full bar to establish exact-hash execution.

## Conditional rubric

Judgment scores apply only to this bounded root/role slice; no average may hide a failed required check.

| Dimension | Score / 10 | Basis |
|---|---:|---|
| Routing correctness | 9.8 | Explicit role gate, unsupported-role denial, guarded root slots and inert legacy redirect. |
| Owner/generation isolation | 9.7 | Owned atomic presentation, entry/store reset, observed ABA and wrong-owner negative traces. |
| Callback authorization | 9.7 | Captured lease plus current owner/raw-auth checks; queued Unknown and held-frame negatives. |
| Lifecycle and recovery continuity | 9.6 | Unknown retention, focus/Back blocking, signup-entry cancellation fallback, retry/sign-out progress. |
| Role saves and invalidation | 9.6 | RoleSelect result/delivery ownership; identity-free repository notifications; startup/lateness races. |
| Role/recovery UI within simulated scope | Pending dark fix | Localized supported choices, disabled states, semantics, large targets, scrolling and complete exit checks. |
| Focused regression | 9.5 conditional | 138/138 Run04; final QA-only deltas and broad bar must pass on these hashes. |
| Evidence quality | 9.5 conditional | Real-policy fixtures, explicit barriers and honest captures; final broad result still required. |

## Limits and acceptance condition

Device UID/startup, real Back/IME/insets, process/activity saved-state restoration, TalkBack, native localization and full production screens remain unaccepted. The current tests prove live-entry retirement and same-entry saveable retention, not process recreation. Render guards for restored entries are statically reviewed; no process-restoration execution is claimed.

A3 exported/deep-link parsing, injection and account replay; A4 opaque preference/mutation writers, credential identity ABA and HomeHub data ownership; A7 signup preference carryover; and A12 already-started global cleanup/sign-out internals remain open. Entire auth boundaries conflated upstream cannot be recovered from userId/email. Production provider/Storage/FCM integration and signed release remain separate.

Final acceptance requires successful full unit tests, lint, debug and release assembly on the reviewed source, with exact command, JUnit counts/skips and outputs preserved. Any material source change requires renewed review. This report does not accept the entire authentication system, app, or release.

## Reviewed SHA-256 hashes

Paths below are relative to the repository. These hashes identify the reviewed production and test seams; the full verification owner retains the complete change manifest.

```text
7A55B0849525C10CAF514DD751E6A69031520469D61A4047D5AAADD4734C4A74  app/src/main/kotlin/com/equipseva/app/features/auth/SessionViewModel.kt
9E6961681D0A2ABDA0FFE2C745B9238DE25425FB4CAF242B7C0EC65725A808D7  app/src/main/kotlin/com/equipseva/app/features/auth/SessionPresentation.kt
47788FA587BECDD8886028037C2F143DA6479AB5AD903FD31F771990877F68C6  app/src/main/kotlin/com/equipseva/app/navigation/RootSessionHost.kt
7E673D91374EE98B0909023A07B8CB3162585CC80F4164AF95DF5316B58E9A1C  app/src/main/kotlin/com/equipseva/app/navigation/AppNavGraph.kt
422C1E51A0F473F200BBD64A0A9EB626D232FBB80E82775368A0492A75728459  app/src/main/kotlin/com/equipseva/app/navigation/AuthNavGraph.kt
FA47E99D8344D04D7F7CFFCFD29C6C0945AA28B990C0EE14645D4897AD8FA49C  app/src/main/kotlin/com/equipseva/app/navigation/MainNavGraph.kt
28C44EC69F424979AA3F9CAD4E738C4CC48C3719221E43F07FE620F4625CEDCC  app/src/main/kotlin/com/equipseva/app/features/auth/SignUpScreen.kt
1AD6F1B67172931B2CE0B5E4D217841C07F8386103C6C882F67CBBF7237C1884  app/src/main/kotlin/com/equipseva/app/features/home/HomeHubScreen.kt
8CAE4A18D14C497C4A3C56302FD0E2F7CE8CF9BB1E8F89972189F3C5F8FD5907  app/src/main/kotlin/com/equipseva/app/core/data/profile/ProfileInvalidations.kt
2593BBAD876519EE202825E26D67E9589A3F1882A3FE2223C2686DB1B0792ADE  app/src/main/kotlin/com/equipseva/app/core/data/profile/SupabaseProfileRepository.kt
31257757CB21708D1941B8FAA29C6EB096B64CFFE85203A3C3220693F234737B  app/src/main/kotlin/com/equipseva/app/features/auth/RoleSelectViewModel.kt
BA7102F4D2E769394BE92B83A93070C1473004B2A169E23C94BF23106D9E6FE8  app/src/main/kotlin/com/equipseva/app/features/auth/RoleSelectScreen.kt
BE2DE81DF7D9E4625AF0AB30106A8CF4AF9B5687A4A1BC1388AA77748CFF186C  app/src/test/kotlin/com/equipseva/app/navigation/RootSessionHostTest.kt
1ECF0BF2F14C5CB8D0784670CCCFC6A04344DB7F82D55C89DFC0B140F326853A  app/src/test/kotlin/com/equipseva/app/navigation/RootDestinationTest.kt
2DF5F09E030A84846CB443C1C48D7F194FB9B0E0C51C96D4E9F26AF4127CFCCF  app/src/test/kotlin/com/equipseva/app/navigation/TabRoutesForRoleTest.kt
5ADB2CBAE76FC8D6A9F9B7A7A46E7AB0D82B3F38FB80A2BCDB68720B56F4BA54  app/src/test/kotlin/com/equipseva/app/features/auth/SessionViewModelIdentityTest.kt
415C531F5E8D7E318AA01731056F6F8D32F4EF3A6D0216EBD9D0585E126A59A2  app/src/test/kotlin/com/equipseva/app/features/auth/RoleSelectViewModelTest.kt
B7196AE494FA7ED6F95559F920CFC6D77F1B3DBB8F664761A31344D181E30CB1  app/src/test/kotlin/com/equipseva/app/features/auth/RoleSelectStateTest.kt
72C3555B197B2CDE5738AA235932C3A99311F6E20B207CA82C4F686D42589435  app/src/test/kotlin/com/equipseva/app/features/auth/RoleSelectScreenUiTest.kt
7D725178A04BB48A6EB354C0F82D153E9E5486BD1F4810E1B4BD0598206B4624  app/src/test/kotlin/com/equipseva/app/navigation/SessionRecoveryScreenUiTest.kt
0C678D28B36A11B8B868BB154F9765D5C7FFB1A75D9C13489F1B68B2CA80402E  app/src/test/kotlin/com/equipseva/app/core/data/profile/ProfileInvalidationsTest.kt
550177810C9CCBE25ECEB48ACE7CFF5F4E10BE025C3C59D66DF40B18958659F9  app/src/test/kotlin/com/equipseva/app/testing/IsolatedUiPackageParser.kt
2FB6CEE063197B55426E2F04EA784A8DCC49B8E4FE6463970368661732409E41  app/src/test/resources/isolated_ui_manifest.xml
```
