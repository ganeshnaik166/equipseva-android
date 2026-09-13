# UI-02 OTP and KYC email sheet: frozen contract

**WIP save on 13 September at the owner's stop request. Not accepted.** The
latest executed review run was 33 tests / 5 failures. Subsequent UI fixes and
test additions are unrun; VM send/cancellation corrections are not implemented.
See [the saved evidence](../evidence/ui-otp-wip/README.md) before resuming.

Base: `2498794a40152d3261e78cca955479d5d3271f83`, branch
`codex/auth-integration-20260911`. Android only; no website updates.

Source inventory found no production caller of `OtpDigitField`. The actual email
code entry is `EmailVerifySheet` in KYC. Its body was mechanically extracted to
an internal function in its own file, unchanged, so tests can mount the real
sheet before behavior changes. Phone collection does not use OTP and remains
unchanged. No login, auth repository, provider or navigation change is implied.

## Decisions before implementation

- Replace the invisible editor and decorative boxes with one visible native
  editor, a persistent localized label and truthful entered/required count.
  Use the approved Inter typography, 16dp corners, 56dp minimum growing body,
  paired light/dark roles and complete supporting/error copy.
- Keep the visible-code presentation of the live sheet. NumberPassword requests
  a numeric-password keyboard; it is not a visual-masking, OEM keyboard or
  clipboard-security guarantee. No code enters descriptions, logs, saved state,
  automatic network actions or new persistence.
- The component preserves its configurable length API and existing callback
  shape. Input filters ASCII digits and caps length, matching the live KYC VM
  contract. Preserve leading zeros, paste, replacement and deletion. The prior
  unused widget accepted Unicode digits; this deliberate correction follows the
  existing live flow, not an invented server policy. Invalid nonpositive length
  is a programmer error. Rendering never writes back or auto-submits.
- Complete-code IME Done and Verify use current callbacks and explicit eligibility.
  Sending permits editing and dismissal; it blocks explicit verification until
  the send completes. Verifying blocks editing, verify, resend and dismissal.
  Resend stays disabled during either operation. Enforce the same admission
  rules in the VM, button, retained callback and IME Done paths.
- The sheet uses real Material modal behavior, scrollable content and growing
  actions. Pending copy says Sending; it must not claim delivery before success.
  Verify failure is visible inline and announced while the code remains for retry.
  Preserve existing effects and send-failure closure policy.
- Retire callbacks on observed email changes and sheet removal; reject a Hidden
  transition while verifying, and intercept native Back before the library
  starts hiding, not just the later dismiss callback. Preserve KYC
  SecureScreen and the native modal's secure-flag inheritance.
- English, Hindi and Telugu; 320dp with actual platform fontScale 2.0 and short
  landscape. Inspect the actual modal window, native EditorInfo and real input
  editing. No activity-only picture can establish modal rendering.

## Test and review gates

Keep existing five OTP smokes. Add executed failing tests before behavioral fixes,
then focused editing/state/VM/modal/native-render checks and a frozen full unit,
lint, debug and unsigned-release bar. Reserve and recheck the shared Gradle slot.
Independent critic and QA must inspect source-bound evidence; each applicable
critical dimension must reach 9.5. Preserve failed tests and harness corrections.

## Review-driven contract revision

The first draft characterized existing Verify-during-send behavior. Review then
reproduced a pending send failure closing the sheet while verification was still
running. The revised contract serializes send and verify while keeping editing,
Close, and the established send-failure closure/effect. The original passing
characterization is preserved in
`docs/evidence/ui-otp-wip/snapshots/KycEmailOtpStateTest.before-send-gate.kt`,
with a hash and rationale in adjacent `policy-revision.json`; new failing targets precede
the production correction. This is an intentional behavior fix, not unchanged
behavior or a relabeled security target.

The first native UI run also exposed Material3 1.3.1 Back hiding the sheet despite
the `confirmValueChange` veto. Its `SheetState.hide()` bypasses that veto; a late
`onDismissRequest` guard preserves state but leaves the sheet visually hidden.
Keep the failing native Back test and require visible-sheet controls before and
after busy changes and actual Back dispatch. Scrim and drag need their own tests.

Repository calls can return cancellation as a failed `Result`. Test that contract
as well as directly thrown cancellation, and check the coroutine is active before
publishing send/verify/profile results. This is coroutine-lifetime protection;
it does not establish account, email or request-generation ownership.

## Explicit unresolved scope

KYC's asynchronous send/verify/profile work lacks complete request, owner and
email fencing. Auth send currently uses `signInWith(OTP)`; provider behavior is
not exercised here. The existing success effect can announce verification when
the refreshed profile is false/null; the complete recovery/ownership workflow
needs its separate security slice. Narrow duplicate admission and inline UI
feedback do not close those findings. Device/TalkBack/OEM IME, native-language,
process restoration, account/provider, A3/A4/A12, dependency and signed-release
acceptance remain open. Do not merge this development milestone to main.
