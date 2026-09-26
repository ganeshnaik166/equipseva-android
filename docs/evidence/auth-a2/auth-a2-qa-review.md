# A2 QA review — root routing and role confirmation

Reviewed 2026-09-11 by `qa_critic_review`. **A2 is not accepted: a confirmed dark-theme primary-button contrast defect must be fixed and tested.** Final acceptance also requires the full Gradle bar and source/artifact closure after that correction. This is not full authentication, app, M1 or device acceptance.

## Evidence and current disposition

QA independently read the preserved run-04 JUnit XML: **138 tests in 10 suites, zero failures/errors/skips**. The breakdown is root NavHost 23, destination policy 8, tabs 8, session identity 56, role ViewModel 23, role UI 7, recovery UI 2, role state 4, profile invalidation 3 and recording preferences 4. Root executed Gradle; QA independently inspected the source, results and images rather than claiming a separate QA-owned run.

The final source adds the mandatory Back dispatch while B's profile is pending and a null-safe test-runner classloader lookup. QA observed the final full-bar unit reports at 01:39:46 UTC: **3,030 tests in 351 suites, zero failures/errors/skips**. The final 23-case root XML, including the pending replacement case, passed at timestamp `2026-09-11T01:36:39.420Z`. QA copied that XML to `auth-a2-qa-final-root-results.xml` and saved the all-suite observation to `auth-a2-qa-full-unit-observation.json`. The Gradle process was still running subsequent tasks at that observation; it was not a successful full-command result yet.

Evidence lives in sibling `work/verification/`: `auth-a2-targeted-04.log`, `auth-a2-targeted-04-results/`, `auth-a2-qa-targeted-04-recount.json`, the final-root XML and all-suite observation above. Root owns `auth-a2-full-01.log` and final command/source/APK preservation.

| Frozen gate | Executed evidence and bounded disposition |
|---|---|
| R01 | Every root/role/recovery UI `@Before` verifies plain Application and empty installed components, permissions and metadata before creating its activity. Actual AppNavGraph uses one explicit real SessionViewModel and inert child slots. Pass. |
| R02–R05 | Cold/live NeedsRole, hospital/engineer main and both engineer onboarding stages, and exact unsupported-role policy execute against production `rootDestination`/NavHost. Unsupported roles go to supported-role selection. No privileged fallback or callback-selected Main. Pass. |
| R06–R07 | Direct A→B, A→SignedOut→A, A→B→A and same-ID changed-generation cases clear actual root-entry ViewModels and nested saved draft/navigation. Mount history checks owner admission. Pass for observed in-process transitions. |
| R08 | Same-login Unknown retains nested draft/entry, hides interactive semantics, clears actual Compose focus, rejects callbacks/DEL and consumes Back; resolving returns the same entry. Onboarding retention also executes. Pass in Robolectric. |
| R09 | Captured callbacks are rejected after owner/generation/gate changes and during Unknown. Held-frame adapter cases prove the VM advances while the old composition remains. The raw-Unknown-before-observer test checks the extra live-auth admission fence. Pass. |
| R10 | Actual root auth-entry VM is cleared while a fake post-sign-in continuation is suspended; cancellation prevents late completion. Server NeedsRole remains recoverable via role selection and another authoritative fetch. Actual legacy phone redirect helper passes cold and entered-route cases. Pass with the accepted A7 role-carryover limitation. |
| R11 | Real Back dispatch cannot recover retired main/role/auth children. Unknown retains the nested stack; ordinary nested Back works. The final pending-replacement test now dispatches Back before profile completion and proves no old VM remount. Final-root XML pass. |
| R12 | All 56 identity tests, including prior A1 adversarial cases and new invalidation/sign-out ordering cases, pass. The complete final unit report is green at the observation above. |
| R13 | Focused XML/logs and failure history preserved; current QA source hashes and full-read spans recorded. Final complete-command exit, source-before/after and archived build artifacts remain root-owned pending gates at this revision. |

## Scores

The scores below describe the already-executed root/role behavior, not accepted overall A2 quality. The newly confirmed dark-theme defect is a hard blocker independent of those passing routing dimensions; no average or previously scoped light-theme test can waive it. The final changed candidate must be reassessed after the correction and its tests.

| Dimension | Current assessment |
|---|---|
| Routing correctness | 9.5/10 — real production policy/host, exact supported-role gates, no direct-main callbacks. |
| Owner/generation isolation | 9.5/10 — observed ABA, replaced root-entry stores and coherent atomic presentation. |
| Callback authorization | 9.5/10 — captured lease plus current VM/live-auth checks, including held-composition and queued-auth schedules. |
| Lifecycle/recovery continuity | 9.5/10 — Unknown retention, entry cleanup, pending/failed refresh, sign-out retry and final pending-Back case. |
| Focused regression | 9.5/10 — 138 targeted and 3,030 final-tree unit reports green; full build bar still pending. |
| Evidence quality | Pending final full-command/source/artifact closure; do not substitute a passing score until that evidence exists. |

## Role and recovery UI inspection

QA fully read the production role screen/VM and both UI suites. Actual production role UI tests cover supported/exclusive radio selection, heading/live-region semantics, disabled saving controls, reachable sign-out, retry and check-again without another save. Recovery tests cover signing-out copy precedence, disabled controls, loading/retry transitions and conditional exit visibility.

QA visually inspected all nine native-Canvas Robolectric images: English 360dp selected/error/retry, Hindi 320dp at 2× text top/full-card/bottom and Telugu equivalents. The new bottom assertions check the complete exit bounds after scrolling through the final hint and observe its callback. Text and controls are readable in these rendered cases; no blocking simulated clipping/overlap found. EN error-top and error-retry images have identical hashes because the whole screen already fits. Reviewed copies and hashes are under `auth-a2-qa-reviewed-ui/` and `auth-a2-qa-reviewed-ui-manifest.json`.

These are draws of the Compose host via Canvas, not device/window screenshots. Layout results check complete visible text coverage, bounds and no ellipsis/height overflow, not every possible glyph's ink or TalkBack behavior. This slice has not established dark-theme fidelity, native locale/font fallback, native IME/insets or human linguistic approval.

### Confirmed must-fix: dark primary-button contrast

The current RoleSelectContent sets its button container to `SevaGreen700` (`#0B6E4F`) but leaves content color inherited. EquipSevaTheme's dark `onPrimary` is `BrandGreenDeep` (`#032F03`), giving **2.378:1** contrast. QA independently checked the source constants and luminance calculation after root identified this defect. That is insufficient for the role-action text. Explicit white on the same green would give **6.255:1**, but the proposed correction has not yet been applied or executed at this report revision.

Required closure: set an appropriate component foreground explicitly, add an actual dark-theme UI/contrast check, preserve the new source hashes and rerun relevant checks. All currently reviewed role Canvas images force light theme, so they cannot establish this missing behavior. The implementation author is waiting for the current full-bar run to finish before making the authorized fix. Do not commit/accept this candidate as having passed the A2 quality gate while this known defect remains.

## Source binding and audit coverage

`auth-a2-qa-source-reviews.json` binds exact SHA-256 and complete line spans for 23 files actually read. It explicitly marks files QA authored/modified; the separate red-team reviewer supplies independent review of those tests and the isolation fixture. A full source read is not a claim of complete app integration or every-line repository audit completion.

Key final hashes:

- SessionViewModel (1–462): `7a55b0849525c10caf514dd751e6a69031520469d61a4047d5aaadd4734c4a74`.
- RootSessionHost (1–194): `47788fa587becdd8886028037c2f143da6479ab5ad903fd31f771990877f68c6`.
- AppNavGraph (1–168): `7e673d91374ee98b0909023a07b8cb3162585cc80f4164af95df5316b58e9a1c`.
- RootSessionHostTest (1–757): `be2de81df7d9e4625af0ab30106a8cf4af9b5687a4a1bc1388aa77748cff186c`.
- IsolatedUiPackageParser/runner (1–106): `550177810c9ccbe25eceb48ace7cff5f4e10be025c3c59d66df40b18958659f9`.

MainNavGraph, HomeHubScreen, SignUpScreen and SupabaseProfileRepository were reviewed as changed spans/call-site behavior, not complete final-file audits. SessionViewModelIdentityTest's new A2 range 787–1096 was reviewed against the previous A1 coverage; no new complete-final-hash file-review claim is made for that large test file here. The RoleSelectStateTest result was inspected; its source is not included in the complete-read manifest.

## Failure history and isolation correction

Run 01 was a compile-only fixture failure from importing a member assertion as an extension. Run 02 executed 137 tests with one isolation failure: AGP-backed Robolectric ignores `Config.NONE`, so the resource APK still exposed production declarations. The oracle was retained. Installed Robolectric bytecode confirmed binary package parsing plus an independent text-manifest receiver path; both diagnostic listings are preserved.

The correction uses an explicitly opted-in test runner and parser shadow. It keeps real compiled resources, substitutes minimal text XML and strips components/permissions/metadata from a fresh uncached parsed descriptor before package installation. Strict preflight runs before every UI activity. Run 03 compiled but rejected 32 UI tests due to a nullable optional parsed-list assumption; the other 106 tests passed. The helper now allows absent optional lists while still requiring actual source providers and verifying the empty installed inventory. Run 04 passed all 138 tests. No production manifest/build configuration or real provider was enabled to make the suite pass.

## Limits retained

- The root tests use real routing and ViewModel lifetime with inert child slots, not the real provider/network/deep-link tree of every destination.
- Same-ID login boundaries wholly conflated upstream remain unobservable until AuthRepository exposes stable login identity. Generations here are process-local.
- Already-started role RPC token binding and global SignOutCleanup internals remain the documented A4/A12 boundary. Admission and stale-result rejection do not make those internals owner-fenced.
- The signup cancellation test uses a fake continuation; automatic signup may require role re-confirmation. Actual signup preference carryover remains A7.
- No Activity saved-state restore/process death, emulator workflow, TalkBack, native IME/window or full authentication/security integration was executed for A2. Those are open, not passing or scored as part of this simulator slice.
