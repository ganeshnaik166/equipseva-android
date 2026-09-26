# Sign-in recovery action target — 26 September 2026

## Ownership and starting point

- Isolated branch: `codex/signin-recovery-target-20260926`; fetched `origin/main` base `3c5f8b6c71275c06fc3ec1da55895cc9cae745c8`.
- Frozen app/test code: `ffbc930f9a97334a7a17605c00f44cab7eb02135`.
- Own `SignInScreen.kt`, a new `SignInRecoveryTargetTest.kt`, and this branch's progress records. Welcome, SignUp navigation, auth repositories and root routing belong to other slices.
- At the base, the right-aligned "Forgot password?" caption is directly clickable with no explicit 48dp layout target or button role. `AuthNavGraph` already passes `onForgotPassword` to the reset route. This is an accessibility/recovery action fix, not a change to account authority or recovery email delivery.

## Callback security/privacy boundary

Source trace: `SignInScreen` invokes only its `onForgotPassword` callback; `AuthNavGraph` maps that callback to `AUTH_FORGOT_PASSWORD`, and `ForgotPasswordViewModel` sends a reset request only after a separate valid-email submission. No sign-in password, token or email is passed by this action. The test asserts the click has no direct sign-in or reset-email repository effect. The hosted reset destination, anti-enumeration behavior and provider delivery remain outside this UI slice and are not certified by it.

## WIP verification ledger

| Evidence | Result |
|---|---|
| Shared Gradle slot | Waited for the other owner's release; then reserved `helper-signin-recovery-20260926`. No competing Gradle process started. |
| Test-first RED | `:app:testDebugUnitTest --tests com.equipseva.app.features.auth.SignInRecoveryTargetTest --no-daemon --console=plain`: 3 tests, 2 failed as expected on original production. The normal action lacked `Role.Button`; the 320×420dp/2×-text target was shorter than 48dp. Disabled behavior passed. Gradle exit 1, local log `C:/Users/lokes/Documents/Codex/2026-09-07/im/outputs/signin-recovery-red-20260926.log`. |
| Focused GREEN | Same command after the minimal fix: 3 tests, 0 failures/errors/skips; `BUILD SUCCESSFUL` in 1m27s, local log `C:/Users/lokes/Documents/Codex/2026-09-07/im/outputs/signin-recovery-green-20260926.log`. |
| Design ratchet | Bundled Python ran `scripts/verify/design_lint.py`: exit 0, all negative signals at baseline, `spacing_tokens` +1. |
| Full unit/lint/debug/unsigned R8 | `:app:testDebugUnitTest :app:lintDebug :app:assembleDebug :app:assembleRelease --continue --no-daemon --console=plain` at frozen code `ffbc930f`: **2,910 tests / 342 suites / 0 failures/errors/skips**; lint **0 errors / 87 warnings / 2 hints**; both assemblies passed; `BUILD SUCCESSFUL` / exit 0 in 9m10s. Local log `C:/Users/lokes/Documents/Codex/2026-09-07/im/outputs/signin-recovery-full-20260926.log`. |
| Independent critic | [Scoped critic](helper-reviews/codex-20260926/signin-recovery-critic.md) **9.7/10 PASS**, no mandatory blocker, on frozen `ffbc930f`. Confirmed 48dp/Button role, unchanged submitting guard and reset-route callback, no credential/token/reset on click, focused 3/0 and full 2,910/0. Physical edge-tap and attempted disabled tap are optional follow-up evidence. |
| Independent QA | [Scoped QA](helper-reviews/codex-20260926/signin-recovery-qa.md) **9.6/10 PASS**, no mandatory blocker, on frozen `ffbc930f`. Checked RED 3/2 → GREEN 3/0, 320×420dp/2× text, full 2,910/0, lint 0 errors/87 warnings/2 hints, debug and unsigned R8. Disabled state is asserted, but no attempted disabled click was run. |
| Hosted CI, main, device/TalkBack | Pending. The two scores accept this local action-target slice only. |

`PRECHECK_LOOSE=1` was used with gitignored compile-only placeholder configuration. The release precheck observed hosted assetlinks, but `EXPECTED_CERT_SHA256` and `app/keystore.properties` were absent; the output is `app-release-unsigned.apk` and cannot be shipped. The Crashlytics upload task completed in Gradle; no independent provider receipt was checked. The shared Gradle reservation was released after the process exited.

## Next steps

The coordinator is reconciling this isolated branch with advancing `main` before hosted CI and integration. The reviewed local branch head `9dbf7f9ca7a584fc62e242004e251a814a7fb46b` was pushed only to `origin/codex/signin-recovery-target-20260926`; it is not on main yet. Keep physical TalkBack/device, hosted password-reset behavior and signed release open. Preserve the distinction between the locally accepted action target and wider auth/security acceptance.

## Integration update — 26 September 2026

Welcome PR1888 passed all six applicable GitHub checks and merged main as `afe2bd33cdc37ca842b921c9817d75cdc645fc74`, after signup navigation PR1889 had merged as `edae85ed50aa9f819a0a4fddaeea50ebae93ff64`. This Sign in candidate merged the new main tree without app-source conflict; only continuity docs required reconciliation. Its original full check and critic/QA scores apply to frozen `ffbc930f`; require combined-head focused tests, design ratchet, and hosted CI before merging this branch. No session-identity fix is included.
