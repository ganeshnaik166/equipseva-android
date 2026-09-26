# P1d-0 sender-only main integration — 26 September 2026

## Frozen boundary

- Branch `codex/p1d0-main-20260926`, isolated worktree `C:/Users/lokes/Documents/Codex/2026-09-07/im/work/equipseva-p1d0-main-20260926`, from fetched `origin/main` `6a6b224681d3595b3c358a029e056e74496bac67`. Verify the current branch and head; the Sharp security PR may advance main separately.
- Selectively cherry-picked the six sender-only commits from the locally accepted helper source `85b91ddd88619bb062468d37b0afa63880759056`: RED tests `0a231783` (source `5f333826`), implementation `7568536b` (`092e8c88`), WebCrypto type fix `c5e25dcb` (`2ca77f19`), test lint fix `de06a1de` (`1834af37`), pinned import config `03a5dccc` (`7b75bb4b`), and older-Deno compatibility `f38f6196` (`85b91ddd`). Exact blobs of the four sender/config/test files match the helper's accepted source.
- Owned code is only `supabase/functions/send_push_notification/{index.ts,push_contract.ts,push_contract.test.mjs,deno.json}`. The blocked P1a/P1b/P1c Android ancestry, SQL grants/schema, app UI and hosted Supabase deployment are not included. An additional path-scoped sender CI workflow is under review; record its exact result before main acceptance.

## Behavior and evidence

The sender re-fetches a notification by webhook ID and uses its stored recipient. FCM visible text is generic, while data is a small allow-list of fetched recipient/notification IDs and validated Android route fields. The sender does not forward arbitrary inbox title/body/data. An FCM 404 counts as an invalid token only with structured `FcmError.UNREGISTERED`; generic 404 and failed transport do not trigger token deletion. Token-only reaping is disabled until versioned ownership exists. Per-token fan-out accounts for successful siblings when another transport throws. This is privacy hardening, not a remote token claim/release protocol.

The helper's test-first record began with a missing-module RED (no runnable assertions) and ended at 13/13 synthetic offline tests under Node 24. On this main-based integration, Node 24 `node --test push_contract.test.mjs` passed **13/13**. Deno **1.46.3** and **2.9.7**, each run from `supabase/functions/send_push_notification/`, passed `check --no-lock index.ts`, `test --no-lock --allow-read push_contract.test.mjs` (**13/13** each) and `lint index.ts push_contract.ts push_contract.test.mjs`; all six commands exit 0. These are local CLI checks, not a Supabase hosted build or device/provider pilot. No Gradle run was warranted because Android files are unchanged.

Independent [critic](helper-reviews/codex-20260926/p1d0-critic.md) and [QA](helper-reviews/codex-20260926/p1d0-qa.md) each scored **9.6/10**, limited to the helper's frozen sender code. The exact code blobs were rechecked after selective port. An integration-level QA/CI review is pending at this document checkpoint. Do not turn the sender score into a whole-app or hosted-deployment score.

## Open gates

1. `device_tokens` registration still depends on a client DELETE that a tracked migration revokes for `authenticated`. Actual deployed table keys/RLS/grants and duplicate-token counts have not been queried. P1d-1 needs a versioned, atomic claim/release/reap contract and disposable two-session race tests before Android registration/logout is accepted.
2. A stale push already selected for account A can still reach a shared physical device after B signs in. Minimal FCM data still carries recipient UUID and route IDs; foreground/background behavior needs a shared-device pilot, and authenticated destination fetch must enforce ownership.
3. Disabling unsafe reaping can leave invalid tokens in the sender's ten-token selection; monitor aggregate failures. A transport exception returns a non-2xx response and configured webhook replay, if any, could duplicate successful siblings. Replay behavior is unverified.
4. GitHub sender CI, Supabase bundling/deploy, real FCM, live database and signed/device acceptance remain separate. Do not deploy this function from a local Deno pass.

Next: finish path-scoped CI, recheck branch diff against current main, obtain integration QA and critic disposition, run PR checks, then merge only this sender slice if green. Keep broad app PR1877 blocked.
