# P1d-0 sender-only main integration — independent critic

Frozen review: 26 September 2026, `codex/p1d0-main-20260926` at `4a21a2ed50855f10eb0c77705a1718c5a1c2e91d`, based on fetched `origin/main` `6a6b224681d3595b3c358a029e056e74496bac67`. Draft PR1886 was opened after the local review; its hosted CI was pending. This report is read-only review evidence, not deployment approval.

**Score: 9.6/10 for the local sender-only integration boundary. No mandatory finding.** The result covers the selective port, sender privacy/error handling, synthetic contract evidence, and the new path-scoped CI definition. It is not an app-wide, release, hosted-runtime, or shared-device score.

## Checks and evidence

- `git diff --name-status origin/main..HEAD` had nine paths: the four `send_push_notification` code/test/config files, `.github/workflows/push-sender-contract.yml`, and four documentation/review records. No Android app file, SQL migration, grant, UI file, or blocked P1a–P1c Android ancestry was included. The merge base was exactly `6a6b2246`; `git diff --check origin/main..HEAD` passed; worktree was clean at review.
- The sender blobs at integration HEAD exactly matched the locally accepted helper code commit `85b91ddd88619bb062468d37b0afa63880759056`: `index.ts` `ff6298d3`, `push_contract.ts` `9630e000`, `push_contract.test.mjs` `3c970904`, and `deno.json` `a6d04883`. The helper's independent sender critic and QA each scored that frozen code 9.6/10 for its local scope.
- I independently reran `node --test push_contract.test.mjs` from the function directory: **13 passed, 0 failed, exit 0**. The integration handoff records Deno 1.46.3 and 2.9.7 `check --no-lock`, `test --no-lock --allow-read` (13/13 each), and `lint` as local coordinator runs; I did not independently rerun Deno or a hosted Supabase bundle.
- The workflow at `4a21a2ed` triggers on sender-function/workflow changes in PRs and pushes to `main`, plus manual dispatch. It grants only `contents: read`; checkout does not persist credentials; Node and both Deno jobs have 10-minute timeouts. The checkout, setup-node, and setup-deno full commit pins match upstream tags v4.2.2, v4.4.0, and v2.0.3 respectively, verified with `git ls-remote`. PR1886 hosted jobs had not run at review.
- The sender re-fetches the notification by ID and uses the stored recipient. FCM visible title/body are fixed generic text; outbound data is a narrow allow-list with validated route IDs. A generic FCM 404 is not treated as token-invalid; only structured `FcmError.UNREGISTERED` on HTTP 404 is counted. Token-only DELETE and token suffix/content logging are removed. A thrown send is counted without discarding successful siblings.

## Exclusions and merge conditions

The sender does not establish versioned `device_tokens` ownership. A stale A push can still arrive after the physical device changes to B, and its data retains A's UUID and a validated route selector. Disabled reaping can let invalid rows occupy the ten-token selection; partial fan-out plus webhook replay may duplicate successful sends. Actual deployed table keys/RLS/grants, Supabase Edge bundling, FCM, foreground/background shared-device behavior, and signed Android/device validation were not tested. These remain P1d-1/provider-release gates, not accepted by this score.

Before main integration, record PR1886 hosted CI and update `docs/MILESTONE_LOG.md`, the P1.3 delivery-ledger row, and the handoff with the exact final SHA/results. Preserve the broad blocked app candidate separately. Do not deploy the function based only on this local review.
