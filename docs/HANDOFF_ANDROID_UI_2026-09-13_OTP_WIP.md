# Android UI: 13 September OTP stop checkpoint

**Owner requested stop and Git push. Work stopped; this is WIP, not acceptance.**
The owner asked for main if possible; main was held because the latest focused
run failed and later corrections were unverified. Push the development checkpoint
only. Do not resume coding or builds until the owner asks to continue.

## Git checkpoints

- Branch: `codex/auth-integration-20260911`.
- Exact starting base: `2498794a40152d3261e78cca955479d5d3271f83`.
- VM/test checkpoint: `9c2da05f06c359a59cee75f5535642c02ed0ea33`.
- UI/test source checkpoint: `df70136a0693833c3e9edb6a332bc6f59e901a74`.
- The later handoff/evidence commit changes documentation only; use `git rev-parse
  HEAD` for its delivery SHA. Main remains `fe4637568059e49f27fb46f8627fe56bccc45e27`.
- No force push, main merge, dependency change, real account action or deployment.

## What is saved

`OtpDigitField` now provides one visible native ASCII editor with persistent
localized naming, progress, current callbacks, explicit Done, inline error and
light/dark design tokens. It previously had no production caller. The real KYC
`EmailVerifySheet` was extracted and wired to this field: scrolling/growing
layout, truthful sending copy, explicit Close and inline errors, plus Hindi and
Telugu strings. Phone/login/provider flows were not changed.

The VM has initial duplicate send/verify/resend/edit guards and inline error
state. It **still permits submit during sending** and **still publishes send
failure state before wrapped cancellation propagates**. Correcting those is
unfinished. Root added UI-level sending guards and a proposed native Back fix
after the last run; these are not compiled/tested yet.

Current sources include 23 VM tests, 15 new UI contracts, 8 native gallery tests
and 5 unchanged OTP smokes. The last five VM cancellation cases are unrun.
The critic's stronger outline/whole-control/host-flag geometry assertions are
also unrun. No code after the stop was implemented; agents finished only their
already in-flight file writes and were stopped.

## Evidence and limitations

Read [the evidence index](evidence/ui-otp-wip/README.md),
[machine-readable ledger](evidence/ui-otp-wip/checkpoint.json), and
[the revised contract](ui-renewal/UI02_OTP.md).

Executed phases: red UI **12/6 failures**, red VM **13/4**, first implementation
**42/1**, review targets **33/5**. The last run failed native Back, retained UI
submit while sending, two VM send/verify overlap cases, and wrapped send
cancellation. XML/logs and original policy characterization are preserved;
no failing desired target was deleted, ignored or renamed to claim green.

First-pass native gallery renders passed, including true platform 2x size,
EN/HI/TE and short landscape. Those captures predate unrun assertion strengthening.
The previous input milestone's 3,198-test full green bar is not applicable here.
There is no full unit/lint/debug/release run for this slice, no critic/QA score,
and no device/TalkBack/provider/signing acceptance.

## Resume in order

1. Fetch and inspect this handoff, current diff, source and the UI-02 OTP contract.
   Preserve all other checkouts. Website/dashboard work stays stopped.
2. Finish VM send/verify serialization and coroutine-lifetime protection at
   send/verify result and post-profile-fetch publication. Preserve explicit
   cancellation propagation before any mutation. Validate the five new synthetic
   cancellation oracles actually deliver a result back to the caller rather
   than passing because a wrapper throws first. Account/email/request epochs
   remain a separate unresolved ownership slice.
3. Run the existing focused tests, preserving new failures. Root's proposed fix
   uses `ModalBottomSheetProperties(shouldDismissOnBackPress=false)` plus a
   dialog-content `BackHandler` calling the stable guarded dismiss. Material3
   1.3.1 `SheetState.hide()` bypasses confirmValueChange on Back; the original
   native API32 failure is real. Busy changes alone did not hide the sheet.
4. Add physical scrim/drag verifying-versus-ready controls and native API34
   predictive Back tests. These were planned, not delivered by the stopped QA
   agent. Keep actual dialog/window ownership and require positive idle controls.
   Predictive visual animation itself is not promised by the proposed handler.
5. Recheck the stronger native gallery assertions, inspect actual renders, then
   have independent critic and QA review. After freezing source, run full unit,
   lint, debug and release compilation. Each critical review dimension must
   reach 9.5 before scoped acceptance. Never apply the score to the entire app.
6. Record signed-release limitations, source hashes and exact check results;
   save/push the development milestone. Main remains gated by A3/A4/A12,
   dependency, account/provider, device and release acceptance.

## Build coordination

Read `C:/Users/lokes/Documents/Codex/2026-09-07/im/outputs/equipseva-build-slot.md`
before Gradle and reserve only if FREE. Root releases its reservation during this
save; recheck live state on resume. No Gradle process remained active at stop.
JDK: `C:/Program Files/Microsoft/jdk-17.0.19.10-hotspot`. SDK:
`C:/Users/lokes/Android/Sdk`; add `C:/Program Files/Git/bin` to process PATH.

```text
.\gradlew.bat :app:testDebugUnitTest --tests '*OtpRenewal*Test' --tests '*OtpDigitFieldUiTest' --tests '*KycEmailOtpStateTest' --max-workers=2 --no-configuration-cache --no-daemon
```

The eventual full bar is `:app:testDebugUnitTest :app:lintDebug :app:assembleDebug
:app:assembleRelease` with the same flags. Existing `PRECHECK_LOOSE=1` permits
unsigned compilation only; keep the strict signing/configuration checks and
unsigned APK rejection as separate evidence. Raw logs and complete first-pass
native captures remain in sibling `work/verification/ui-otp-20260913`.

KYC's existing provider send uses `signInWith(OTP)`, its asynchronous work lacks
complete owner fencing, and its success effect can announce verified for a
false/null refreshed profile. These remain explicit security/workflow findings,
not solved by UI polish or the narrow admission changes.
