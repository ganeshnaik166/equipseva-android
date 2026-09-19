# A2 root navigation: independent QA contract

Prepared 2026-09-11 by `qa_critic_review`. This freezes the bounded root-routing checks before implementation and execution. No passing score or device acceptance is claimed.

## Scope and source baseline

Read the current `AppNavGraph.kt`, A1 `SessionViewModel.kt`, `AuthNavGraph.kt`, `UserRole.kt`, Compose test/build infrastructure, and isolated uiSmoke host/runner/readme. Existing root behavior allows NeedsRole to fall into main, permits auth/onboarding callbacks to navigate directly to main, and obtains default Hilt session ViewModels again in nested hosts. The A1 session generation is private and its public Loading state alone cannot distinguish account replacement from a transient Unknown.

The agreed production seam is one atomic `SessionPresentation` containing state, observed owner/generation, retained same-login state, base-profile completion and auth-resolution status. `AppNavGraph` collects one presentation from its explicit root ViewModel. An internal `SessionRootHost` owns the actual root NavHost, keys, routing effects, render guards and callback arbitration. Tests replace only screen rendering with inert slots. They must not implement a second routing policy.

Proposed slots: auth(onProfileSaved), role(onRoleSaved,onSignOut), onboarding(role,baseDone,onSaved), main(role,onProfileSaved), pending(onRetry,onSignOut). Unknown, deferred and admin raw roles use a recovery slot and must not acquire a hospital/engineer main or onboarding surface. Final Kotlin signatures remain root-owned.

## Smallest executable harness

- One new `app/src/test/kotlin/com/equipseva/app/navigation/RootSessionHostTest.kt`, owned by QA after signature freeze and ownership transfer. Existing JUnit, Robolectric, Compose test, lifecycle and navigation runtime dependencies are sufficient; no navigation-testing dependency is required for rendered-node assertions.
- Use Robolectric SDK 34 and plain `Application`; do not launch MainActivity, EquipSevaApplication or HiltTestApplication. Prefer a manifest-free manual empty ComponentActivity with `createEmptyComposeRule` if needed to exclude merged production providers. First prove this harness starts, renders and disposes. An alternative minimal test-only manifest may declare only that empty host. Merely overriding Application is not proof that merged providers are absent.
- Compose fake slots expose unique semantic tags and callback buttons. Record `DisposableEffect` mount/dispose events, current owner and destination. Do not count recompositions as mounts. This catches an unauthorized intermediate mount hidden by a later redirect.
- The fake main slot uses an actual nested NavHost (home and inert detail), rememberSaveable text, and a test ViewModel tied to the actual root back-stack entry. Track that ViewModel's identity/onCleared. This distinguishes real lifetime reset from a changed label.
- Most route cases drive immutable presentation values through Compose state on the UI thread. At least one adapter case mounts the public AppNavGraph with an explicit real SessionViewModel and strict fake dependencies plus inert slots. Any nested Hilt lookup should fail in this plain host, proving the explicit root instance is used.
- Pure ViewModel tests may use the coroutine test scheduler. Compose tests use the rule's main-thread/idle primitives and explicit barriers; do not layer an undriven StandardTestDispatcher underneath the Android main looper. No sleeps or real network. Close manual activities, ViewModelStores and suspended fake work.

## Frozen acceptance matrix

| ID | Stimulus and observable result |
|---|---|
| R01 | Isolation/adapters: empty test host renders with no production application/provider/repository startup; all fake slots explicit. The passed root VM drives the host and receives a valid refresh exactly once; no implicit second root VM. |
| R02 | Cold NeedsRole: only role gate mounts. Cold Loading then NeedsRole must never mount main/onboarding, including mount history before idle. |
| R03 | Live Ready to NeedsRole and NeedsRole to validated Ready: role gate replaces main immediately; role completion requests refresh but cannot itself grant main. Back cannot recover the displaced main/gate. |
| R04 | Validated hospital/engineer Ready maps to the intended main slot. Hospital onboarding, engineer base onboarding and engineer payout onboarding select their explicit slots/parameters. Saved callback requests authoritative refresh; no direct-main fallback before updated presentation. |
| R05 | Blank, unknown and admin raw role in both Ready and NeedsOnboarding, plus deferred known roles per the agreed support policy, use recovery. Zero main or role-specific onboarding mounts and no engineer/hospital fallback. |
| R06 | Observed A to B with same role/gate and with intervening Loading: old-owner content is neither rendered nor actionable before navigation effects settle. Old entry ViewModel clears, nested detail and saveable draft do not transfer. B starts with fresh content. |
| R07 | Observed A to SignedOut to A and A to B to A: same user ID with a new generation resets entry/store/navigation/draft. A Compose observer that sees only final A still resets because generation changed; this is not a claim to detect boundaries lost upstream of SessionViewModel. |
| R08 | Same-owner transient Unknown from main detail or onboarding preserves entry ViewModel, nested destination and draft. Blocking overlay removes/blocks interactive semantics and focus actions; retained callback invocation is rejected. Same owner resolving returns the same entry/draft without an extra main mount. Initial Unknown with no validated retained gate stays pending. |
| R09 | Captured old auth/role/onboarding/main/pending callbacks invoked after owner replacement cannot refresh or sign out B. During resolvingAuth, they cannot bypass the gate. Repeated valid callback behavior is explicit and cannot navigate directly to main. |
| R10 | SignedOut mounts auth and clears old authenticated navigation. Successful authentication/profile-saved callback cannot choose main while NeedsRole, onboarding, pending or unsupported-role state remains authoritative. |
| R11 | Root back-stack behavior is exercised with actual back actions/pop operations: no unauthorized destination resurrection after gate/owner transitions; ordinary same-owner main/detail Back remains correct. Test during pending transitions as well as after settling. |
| R12 | A1 regression selectors remain green after SessionPresentation integration. Owner/state/base completion are one coherent observation; email-only updates and same-login refresh do not reset navigation, while observed generation changes do. |
| R13 | Final source hashes, command, exit status, JUnit counts/skips and relevant logs are preserved. Required negative cases execute; no ignored tests, success-by-timeout or semantic-only claim of device accessibility. |

The literal unknown/deferred-role policy and callback ownership must be agreed in code before assertions are finalized. Any scope change is recorded rather than silently weakening an oracle after failure.

## Scoring and hard gates

After final-source execution only, independently score: routing correctness; owner/generation isolation; callback authorization; lifecycle and recovery continuity; focused regression; evidence quality. Each applicable dimension must reach 9.5/10 and every mandatory row must pass. No average can hide a failed row. Unknown or unexecuted evidence is unassessed, not a passing score. A fixture that bypasses the real production root policy is a hard blocker.

Planned focused command after exclusive Gradle ownership is granted: `gradlew.bat :app:testDebugUnitTest --tests com.equipseva.app.navigation.RootSessionHostTest --tests com.equipseva.app.features.auth.SessionViewModelIdentityTest --tests com.equipseva.app.testing.RecordingUserPrefsTest --max-workers=2 --no-configuration-cache`. Root/role-author selectors are added to the final integrated bar once filenames are frozen. Baseline/source failures and harness failures are preserved and distinguished.

## Explicit limits

These tests prove production root routing with inert screen slots, not complete production destination behavior. Actual SignUp role-save ordering, RoleSelect save ownership, Profile/hub refresh wiring and other consumers of device-global preferences need their own integrated evidence. A captured callback must not be treated as permission to act on a newer account.

The uiSmoke target is a separate opt-in native scaffold with an isolated package, no permissions and a guarded host. Its placeholder host has not established root navigation or actual device behavior. Do not combine `-PuiSmoke=true` with the normal JVM command. Device UID/startup, real Back/IME/insets, process recreation, TalkBack focus/announcement behavior, full workflows and real auth/Storage/FCM/global-cleanup integrations remain separate unless actually executed. No full-app, M1, M2a or release score follows from this bounded matrix.

## Contract and test freeze, before first A2 execution

The agreed recovery for unknown/admin/deferred roles is specifically the supported-role chooser (`RootGate.ROLE`), never a role-specific main or onboarding slot. The production host is named `RootSessionHost`. Root callbacks pass their captured `SessionOwner` into the explicit root SessionViewModel, whose endpoint must recheck ownership and resolved auth before admitting effects. This closes the interval in which the VM advances before Compose renders a new frame.

The frozen test set is 23 `RootSessionHostTest` cases, eight `RootDestinationTest` cases and eight existing `TabRoutesForRoleTest` cases. The root suite includes held-frame A-to-B and Unknown callback negatives with explicit fixture preconditions, an auth-entry ViewModel cancellation barrier after automatic sign-in, and two tests of the actual `legacyPhoneAuthRedirect` helper (cold legacy start and entry from another auth child). The auth cancellation case proves root-entry lifetime and the recoverable NeedsRole fallback with a fake suspended continuation; it does not execute the actual signup SDK or prove saved role carryover. Role re-confirmation when the server profile lacks a confirmed role is the accepted A2 fallback; preference carryover remains A7.

The manual manifest-free Compose host and these tests have not yet executed at this freeze. Source hashes: RootSessionHostTest `e52cf1290a1135b97dca78ad5bf9b6c7d0193723c28cbfcdf7b9355282ddbccf` (1–752); RootDestinationTest `1ecf0bf2f14c5cb8d0784670cccfc6a04344db7f82d55c89dfc0b140f326853a` (1–78); TabRoutesForRoleTest `2df5f09e030a84846cb443c1c48d7f194fb9b0e0c51c96d4e9f26af4127cfccf` (1–98). QA authored the tests; the separate red-team reviewer will assess their scheduling and oracles. No numeric score is assigned before exact-source execution.
