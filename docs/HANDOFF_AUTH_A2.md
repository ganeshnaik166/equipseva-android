# A2: root session routing and role confirmation

## Current local disposition, 12 September 2026

The historical dark-button blocker below is closed, together with an adjacent
radio-contrast correction. The combined A2/A10 local slice passed independent
critic **9.62** and QA **9.50**; the separate Welcome slice passed critic **9.59**
and QA **9.50**. Tested application source is committed at
`7f3c5eaa8c8ae218433f3217b86ea34e9a08691b` on `codex/auth-integration-20260911`.
All 768 source/configuration hashes match the verified candidate; 3,110 unit tests,
lint, debug and unsigned R8 assembly passed. These are local component approvals,
not full-auth, real-device, main-integration or signed-release acceptance.

Resume from [HANDOFF_ANDROID_UI_2026-09-12.md](HANDOFF_ANDROID_UI_2026-09-12.md).
Exact results and retained failures are in
[verification.json](evidence/auth-integration/verification.json). The earlier
checkpoint and its failure history below remain historical evidence.

## Historical 11 September WIP checkpoint

WIP save checkpoint, 11 September 2026, on `codex/security-foundation-20260907`.
Starting checkpoint `64107db7`. The owner requested immediate save/commit/push
after reporting limited remaining usage. A2 is not an accepted milestone.

Final saved code passed 3,030 unit tests across 351 suites (zero failures, errors
or skips), lint, debug assembly and release R8 assembly. Full command completed
successfully in 7m 51s. Release used `PRECHECK_LOOSE=1`, not production signing.
See [verification.json](evidence/auth-a2/verification.json) for commands, source
hashes, preserved failure history and scoped evidence.

**Resume first:** RoleSelect's fixed green button inherits a dark-theme foreground
with only 2.378:1 contrast. An explicit white foreground gives 6.255:1; implement
the minimal fix and actual light/dark render contrast tests, then reverify and
request independent critic/QA closure. The fix/tests were not written before
the save request. Nine existing simulated previews cover light theme only.

The saved critic/QA reports are conditional, not acceptance. Their earlier
full-command-pending statements are superseded by the successful full command
above; the dark-theme blocker remains open.

The owner resumed and explicitly removed model/reasoning-setting confirmations.
Continue the authorized bounded work, then independent critic and QA review.

## Frozen behavior

- One root SessionViewModel publishes owned state, local login generation, base
  onboarding state and auth-resolution status atomically.
- NeedsRole and unsupported/deferred/admin roles show an explicit hospital or
  engineer chooser. Preference defaults never establish root/main role authority.
- Child saves request a server refresh. They cannot directly grant Main.
- Root entries include login generation and validated role. Replacement login,
  role or gate retires the previous entry, child ViewModels and nested stack.
  Render guards deny stale restored/exiting content before navigation settles.
- Same-login Unknown hides and blocks the retained validated subtree, preserving
  draft/navigation until resolution. Captured actions are checked again inside
  the root VM against the login owner; resolving auth does not admit UI actions.
- A current-owner save invalidates its previous gate until fresh profile success.
  A repository-wide role notification only requests a background owned refresh:
  a late A save must not destroy B's form. No data or role is trusted from it.
- RoleSelect permits only add_role for hospital_admin/engineer, without local
  preference writes or direct navigation. Missing/Unknown auth is rejected
  immediately. Save results/effects are guarded through observed relogins.
- Setup/recovery has an explicit sign-out exit, error/retry and progress UI.
  Role choices are scrollable/localized with radio semantics and large targets.

## Product decision: signup role confirmation

Root admission replaces the auth entry as soon as the SDK reports a signed-in
account. This may cancel the legacy signup VM before its selected-role RPC
finishes. If the server has not confirmed a role, the new role chooser asks the
user to confirm it. This redundant confirmation is an accepted A2 fallback; no
engineer default is inferred. A successful role RPC triggers root revalidation
even if the old signup screen is already gone. Carrying the signup preference
across that boundary and broader signup mutation ownership remain A7/A4 work.

## Required evidence before acceptance

The independent QA contract is [AUTH_A2_QA_CONTRACT.md](AUTH_A2_QA_CONTRACT.md).
Freeze final source hashes and
preserve compile/harness/test failures and successful commands. Required scope:
root production NavHost with inert slots and real-VM adapter, lifetime/Back/draft
behavior, captured stale callbacks, active-role picker saves and UI, repository
invalidation, A1 regressions, full unit suite, lint, debug and release assembly.

The final focused bar passed 138 tests; the full bar above also executes the
last pending-Back regression. Acceptance remains blocked on dark contrast.
No device, TalkBack, native localization or human usability
acceptance is claimed by JVM tests. Main/prod integration gates remain open.

## Remaining boundaries

A3 exported/deep-link parsing and account replay; A4 opaque preference/repository
writers and HomeHub data loading; A7 signup carryover; A12 already-started cleanup
and sign-out internals; repository identity for entirely unobserved same-user
boundaries; INT-DEVICE-01, provider/Storage integration and signed release.

Do not promote this bounded slice to full-app, full-auth or release acceptance.

## External helper ownership

- [Claude task pack](helper-tasks/CLAUDE_HELPER_TASKS_2026-09-11.md): A3 security
  contract, A4/A12 audit, both-role UX workflows and QA plans; docs/review only.
- [GPT-5.3-Codex task pack](helper-tasks/GPT53_HELPER_TASKS_2026-09-11.md): A10
  engineer-status logic in DeepLinkHost, independent parser regression tests,
  and a bounded accessibility report. Separate fresh branch/worktree.
- Coordinator retains A2 files and integration ownership. Helpers do not merge
  main, alter production data or compete for the laptop's Gradle slot.
