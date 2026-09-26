# EquipSeva status — 9 September 2026

Codex is continuing Claude's app. The latest bounded reliability slice is
committed, pushed and green on GitHub. The overall app has not passed the 9.5
quality gate.

## Saved work

| Item | Current state |
| --- | --- |
| GitHub main | Claude's `fe463756`; original checkout preserved |
| Development branch | `codex/security-foundation-20260907` |
| Latest commit | `efd1d90b`: atomic repair-photo attachment/evidence finalizer and regressions; clean and pushed |
| GitHub checks | Android and backend passed on the exact commit; Linux finalizer race artifact retained |
| Production | No migration or app release deployed by this work |
| Interface | First interactive hospital/engineer home draft built and checked; Android integration remains open |

[Latest commit](https://github.com/ganeshnaik166/equipseva-android/commit/efd1d90bfefb21917a5cc00e35be67d4594eec2c)
· [Android check](https://github.com/ganeshnaik166/equipseva-android/actions/runs/34325210184)
· [Backend check](https://github.com/ganeshnaik166/equipseva-android/actions/runs/34325210244)

## Verified in this continuation

- Round3823 adds a narrow authenticated-engineer finalizer. It locks the job,
  validates assignment and the owned Storage object, appends the intended photo
  once, and registers evidence in the same transaction. Downstream failure rolls
  back the attachment; unauthorized retries cannot receive an existing ledger ID.
- Independent QA passed **87 semantic tests**, **60 unchanged authorization
  regressions**, **3 omitted-claim cases**, and a fresh **27-schedule native
  replay with 322 assertions and 26 observed waits**. The author run passed the
  same native schedules. The initial harness-only preflight failure is preserved.
- QA and critic accepted all F01–F10 local gates at **9.5/10 in every bounded
  dimension**: correctness, security, concurrency, regression and evidence.
- Root's complete backend command passed 60 authorization, 87 finalizer, 51 cron
  and 25 snapshot tests; 21 parser tests also passed.
- GitHub backend and Android workflows passed on `efd1d90b`, including unit tests,
  lint, debug assembly and release R8 assembly. No fresh device journey was run.

This is the server portion of REL-01. Existing Android photo delivery still uses
whole-array replacement and lacks durable prepared/uploaded/registered stages,
claim leases, persistent recovery and account-generation fencing. Full schema,
real Auth/PostgREST/Storage, immutable-byte and production rollout gates remain
open. Main and production were intentionally left untouched.

## What follows

1. Add the Room v5 repair-photo delivery lifecycle with prepared-byte checkpoints,
   conditional claims, persistent NeedsAttention state and account isolation.
2. Replace the Android whole-array writer with the new finalizer, then execute
   process-death, cancellation, concurrent worker and account-switch tests.
3. Run complete-schema and real Auth/Storage integration before merging the
   combined security/reliability line to main or applying migrations.
4. Continue the interface program from the checked home preview into login,
   hospital and engineer workflows, accessibility, language and recovery states.

The audit inventory has **25 complete, 12 partial and 7,352 pending file reviews**.
It includes history/reference material, so these are not an app completion
percentage. Main pushes remain authorized after the applicable integration and
release gates pass.

[Current checkpoint](<C:/Users/lokes/Documents/Codex/2026-09-07/im/outputs/equipseva-execution-checkpoint.md>)
· [Master plan](<C:/Users/lokes/Documents/Codex/2026-09-07/im/outputs/equipseva-master-plan.md>)
