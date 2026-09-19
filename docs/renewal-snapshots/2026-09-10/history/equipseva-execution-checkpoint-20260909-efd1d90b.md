# EquipSeva execution checkpoint

Updated 9 September 2026 after the fifth candidate passed both exact-commit
GitHub workflows. The renewal program remains in progress. No whole-app or full
milestone acceptance is claimed.

## Repository and ownership

The owner delegated ongoing execution to Codex, including independent agents and
pushing completed verified features or milestones to main. Use the saved gates,
fetch before committing and preserve concurrent work. Main integration remains
deferred because real service/device and combined release evidence is incomplete.

- Original checkout: `C:/Users/lokes/equipseva-android`, preserved.
- Isolated implementation checkout:
  `C:/Users/lokes/Documents/Codex/2026-09-07/im/work/equipseva-android`.
- Branch `codex/security-foundation-20260907` is clean and pushed at
  `efd1d90bfefb21917a5cc00e35be67d4594eec2c`.
- Latest fetch before commit confirmed the branch remote at its parent `c927f7f4`
  and `origin/main` at Claude's `fe463756`. No main merge or production action.
- Claude handoff remains `docs/HANDOFF_2026-09-07_0645UTC.md`; earlier refresh
  detail is in `docs/SESSION_REFRESH_round3816.md`.

## Implemented candidate stack

1. `c71c2f35`: r3821 evidence authorization and request-draft account/session
   isolation. Local SQL/Android gates passed; real service/device integration open.
2. `05b73b52`: safe cron error reporting and response diagnostics. Local reporting
   gates passed; production daily snapshot recovery remains unconfirmed.
3. `a74b2dae`: guarded r3822 storage-snapshot timeout migration and rollout guide.
   Local PGlite/native/PostgREST evidence passed; production deployment open.
4. `c927f7f4`: native r3821 authorization concurrency harness and Linux CI job.
   Author and QA each passed 27 schedules/252 assertions/33 observed waits.
5. `efd1d90b`: r3823 atomic repair-photo finalizer plus semantic and native
   regressions. This is the current exact candidate.

## r3823 finalizer result

`finalize_repair_photo` is an authenticated-engineer-only SECURITY DEFINER RPC.
It accepts only a repair job, before/after kind and canonical receipt. It takes
the job `FOR UPDATE` first, then locks the engineer mapping and Storage object,
validates current assignment/owner/path/size, appends the path if absent and calls
the unchanged r3821 `register_evidence` in the same transaction. The typed result
contains `ledger_id uuid` and the canonical bucket-relative `attachment_path`.

The migration fails closed if the r3821 dependency body, signature, owner,
security/search-path/volatility or ACL contract drifted. Reapply also refuses an
existing helper with an unknown owner, PUBLIC/service/extra-role grant or client
grant option. Migration-time lookup uses `pg_catalog, pg_temp`; postconditions
verify the installed function and grants. Apply requires one intended schema
executor and readback/cache validation.

Attachment and ledger insertion roll back together on collision, invalid metadata
or injected downstream failure. Legitimate retries preserve the original UUID and
metadata. Current authorized engineers may restore a removed attachment; explicit
user cancellation/tombstone semantics are later work. Existing direct r3821 calls
still reject unattached objects.

## Verification evidence

- Frozen semantic source: 87/87 tests passed independently and in root's full
  backend run. Unchanged r3821 authorization: 60/60. QA-only literal omitted-claim
  supplement: 3/3 denials with complete state unchanged.
- Author native run: 27/27 schedules, 322 assertions, 26 observed blocker edges,
  PostgreSQL 17.11, clean shutdown. Report SHA256
  `5a7b64147989a5e00ccfbf04525433ababe15645c77283ce4ea13e831b3bd8a5`.
- Independent QA native replay: 27/27, 322 assertions, 26 waits, clean shutdown.
  Report SHA256
  `7f5f45161ad53aee945eb784bf3ee8238affc48243dfd2c5af4552be225499d2`.
- The first native attempt failed before all scenarios because the harness
  compared a JSON catalog representation with text. That failure and its clean
  shutdown are preserved; QA reviewed the two-line harness-only correction.
- Root backend command passed 60 evidence + 87 finalizer + 51 cron + 25 snapshot
  tests. The daily response parser passed 21/21. No credential or production URL
  was read by these tests.
- Independent QA and critic each passed F01–F10 and scored correctness, security,
  concurrency, regression and evidence at 9.5/10. This is a bounded local server
  score, not an app score.
- Exact-commit GitHub backend run `34325210244` passed all three jobs: focused
  backend semantics, existing evidence concurrency and new finalizer concurrency.
  Finalizer artifact `10093465156` is retained for 14 days and was reported at
  121,133 bytes.
- Exact-commit GitHub Android run `34325210184` passed unit tests, lint, debug
  assembly and release R8 assembly. Android source did not change and no fresh
  local/device run was performed for this server slice.
- Candidate manifest: 7,389 tracked paths, digest
  `8cc741f229d10310281a39b1a1a6b1e3c0bd8b5e7a1a5a87ca4170b66372d894`.

Primary local records:

- `work/planning/repair-photo-finalizer-implementation.md`
- `work/planning/repair-photo-finalizer-qa.md`
- `work/planning/repair-photo-finalizer-independent-critic.md`
- `work/verification/repair-photo-finalizer-author/evidence-concurrency-20260909-130043-811516/evidence/report.json`
- `work/verification/repair-photo-finalizer-qa/evidence-concurrency-20260909-130357-c3753b/evidence/report.json`

## Current limits and next slice

This migration closes only the cooperating server append/register transaction.
The existing Android handler can still lose a reference with whole-array
replacement, delete the only local bytes after partial progress, swallow the
evidence enqueue failure and self-cancel through one-shot REPLACE scheduling.

Next implement the scoped Room v5 `repair_photo_deliveries` lifecycle described
in `work/planning/photo-delivery-recovery-design.md`: stable operation/path,
prepared immutable bytes, Prepared/Uploaded/Registered/NeedsAttention phases,
conditional expiring claims, bounded retries, cleanup as a separate stage and
account/session-generation fencing. Then replace only engineer before/after proof
with r3823; do not rewrite KYC/chat/payment queues in this slice.

Frozen future cases R01–R20 remain the guide. Required follow-up includes kill
boundaries, lost upload response, no duplicate re-encoding, concurrent drains,
claim expiry, cancellation, sign-out/account switch, retry exhaustion and cleanup
after registered checkpoint. Check-in/completion prerequisite policy still needs
an explicit product/server decision and cannot be silently changed in transport.

Before rollout or main integration, run a complete migration-built schema with
repair triggers/RLS/column grants and real Auth/PostgREST/Storage upload/download.
Confirm deployed versions/owners, actual bytes versus receipt, PostgREST cache,
assignment provenance and exclusive schema execution. Production was last
observed through r3819; r3821/r3822/r3823 are not deployed.

Other open work: isolated device draft/account/photo/lifecycle journeys, complete
login and both-role prototype, Android interface/accessibility/language work,
payment rail, FCM runbook, web debt, deferred-feature triage and Supabase token
cleanup. Do not print the token at `C:/Users/lokes/eqs-token.txt`.

Audit inventory: 25 complete, 12 partial and 7,352 pending rows. The inventory
includes history/dependencies/generated material and is not an app-completion
percentage. All test clusters/listeners and owned sessions are stopped; no
browser/build/database helper remains active.
