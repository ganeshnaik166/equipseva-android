# EquipSeva execution checkpoint

Updated 10 September 2026 after A1 passed local checks and exact-commit GitHub CI.
The overall renewal remains in progress; this is bounded checkpoint acceptance.

Owner requested end-of-day save and stop on 10 September. Save these records to
GitHub and resume tomorrow only when the owner returns. A2 has not been started.

## Repository and ownership

- Isolated checkout: `C:/Users/lokes/Documents/Codex/2026-09-07/im/work/equipseva-android`.
- Branch: `codex/security-foundation-20260907`.
- HEAD and remote branch: `d140c19b20bb0a6e458df0f0a8b4f7b233b78876`.
- Tracked tree clean; untracked repo-local `work/` contains retained verification evidence.
- Remote main was rechecked at `fe4637568059e49f27fb46f8627fe56bccc45e27`.
- No main merge or production migration/app deployment in this checkpoint.
- Main pushes remain authorized once applicable integration/release gates pass.

## Candidate changes since the previous output checkpoint

| Commit | Scope |
| --- | --- |
| `1054e473` | Merged stable Claude integration-test helper |
| `4a2677ea` | Room v5 durable repair-photo delivery and recovery |
| `b8b18906` | Deferred production device evidence into INT-DEVICE-01 |
| `5d512462` | Hospital Home primary Request service action |
| `396bcf37` | Opt-in isolated native UI smoke target |
| `8a52417a` | Reviewed auth-audit fixtures and corrected handoff |
| `d140c19b` | A1 session bootstrap ownership and regression tests |

The prior checkpoint and detailed r3823 evidence are preserved in
`history/equipseva-execution-checkpoint-20260909-efd1d90b.md`.
Do not follow its obsolete instruction to start Room v5 again.

## A1 evidence and scope

A1 creates a fresh local generation for each observed sign-out/account replacement,
fences profile requests by generation and request revision, checks live auth before
effects, and publishes role/onboarding together after required preference writes.
Storage failures preserve an initial Loading or previously validated same-login gate.

- Independent forced targeted rerun: 43 identity + 4 preference tests passed; 45/45 Gradle tasks executed.
- Full debug unit suite: 2,951 tests, zero failures/errors/skips.
- Debug lint and assembly passed. Release R8 assembly passed with `PRECHECK_LOOSE=1`.
- Release verification used missing-keystore CI mode; it is not a signed production release.
- Android CI: https://github.com/ganeshnaik166/equipseva-android/actions/runs/34498001037 (success).
- Secret scan: https://github.com/ganeshnaik166/equipseva-android/actions/runs/34498001057 (success).
- QA: 9.5 in all six scoped dimensions. Critic/red-team: 9.6 to 9.8.
- Logs: `../work/verification/auth-a1-final/`; preserved red tests: `../work/equipseva-android/work/verification/auth-a1-impl/`.
- Repo handoff: `../work/equipseva-android/docs/HANDOFF_CLAUDEDEV_AUTH_AUDIT.md`, section 9.

Entirely unobserved same-user auth boundaries need repository-issued identity.
Already-admitted cleanup/sign-out and token dependency internals remain open.
Root navigation can retain an old host during replacement-account Loading; role
writers need authoritative refresh wiring. Cold offline/storage failures have no
visible retry interface yet. A1 does not close whole-auth or device acceptance.

## Next step and current pause

A2 must implement the root role gate and integrate the shared session owner:
NeedsRole shows role selection; unknown roles cannot acquire engineer tabs;
account replacement cannot retain the prior account host; successful role saves
trigger authoritative refresh and cannot bypass the root gate.

The owner explicitly requires a pause before a material reasoning-level change.
The last response requested Extra High for A2 and is awaiting confirmation.
Do not treat a heartbeat, elapsed time, or a generic model-switch event as that
confirmation. Resume A2 only after the owner confirms the setting. Checkpoint
maintenance is complete; unattended continuation is paused at this boundary and
remains paused for the owner's end-of-day stop.

## Remaining program gates

INT-DEVICE-01, native UI smoke/runtime, TalkBack, Telugu and large-text verification,
human workflow validation, full auth/navigation recovery, complete backend/schema
and real Auth/Storage integration, payment rail, FCM runbook, and signed release
remain open. Production migrations were last recorded through round3819.
The audit CSV remains an incomplete inventory; earlier aggregate counts are stale.
Use the A1 review addendum and final hashes without inferring full-app coverage.
