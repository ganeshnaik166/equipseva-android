# Handoff — security audit and code debugging (Claude, 26 September 2026)

Status: **three SQL fix batches implemented and locally proven on branch `claudedev-build-20260923`; independent critic/QA reviews were started but stopped before reporting, so nothing here is accepted; nothing is applied to production.** Stopped at the owner's request ("save everything for now and stop"). Governing plan: [PRODUCT_PLAN.md](../PRODUCT_PLAN.md). Resume point: [CURRENT_STATE.md](CURRENT_STATE.md).

## What happened this session

1. **Coordination.** Surveyed Codex's work on 26 September: sign-out/session ownership (P1b–P1d), push-sender privacy, Welcome/SignUp/SignIn screens and the Sharp web dependency. First picked P5.3 district discovery (paused, survey kept privately), then the owner redirected to **security audit and code debugging**. The owner relayed a slot-handoff request; Codex finished its run and released the shared Gradle slot. Claude held it from 15:26 to 15:59 UTC and released it (`FREE - released by Claude at 2026-09-26 15:59:12 UTC`).
2. **Branch kept current.** `origin/main` merged into the branch as `e4593402`. There were two append-only docs conflicts (milestone log, ledger P3.1), resolved by keeping both sides. Full bar on the merged tree: **3,014 unit tests / 350 suites / 0 failures / 0 errors**, lint **0 errors / 88 warnings / 2 hints**, `assembleDebug` built.
3. **Audit.** A ten-angle read-only audit covered payment and other edge functions, SQL function authorization, RLS and storage, the Android surface, cross-party privacy, CI/web, and correctness in the data layer, ViewModels and server logic. It produced **135 raw findings** (7 critical / 20 high / 57 medium / 51 low). Adversarial verification was **in progress and was stopped**, so only the items fixed below were verified, and those were verified by hand against the production catalog snapshot (2026-09-18) and each function's latest migration.

## Fix batches (SQL only; not applied to production)

| Batch | Migration | What it fixes | Local proof (PGlite 0.5.8) |
|---|---|---|---|
| S1 `34345b66` | `20263903000000_round3826_engineer_location_privacy_sealed_bids.sql` | Public profile coordinates were "fuzzed" by an offset anyone could compute from the public engineer id and subtract, exposing every verified engineer's exact saved base location to anonymous callers. Directory and recommendation distances allowed trilateration. The round732 regression returned raw KYC addresses and had re-granted anonymous access. The bid list showed every competitor's sealed bid to any bidder. The directory tier badge never rendered (wrong overload), and multi-role engineers were hidden | `engineer_location_privacy.test.mjs`: new **22/22**, negative controls **10/10** fail on the old definitions, non-regression **10/10** |
| S2 `27a92db0` | `20263904000000_round3827_nearby_repair_jobs_definer_restore.sql` | The engineer "nearby jobs" feed (default 50 km) raised 42501 for every engineer with a saved base, because round 20260627 silently reverted the definer fix. Restored, with the clamps and assigned-job visibility, and hospital coordinates on the coarse grid | `nearby_repair_jobs_feed.test.mjs`: new **9/9**, controls **2/2** fail with the production 42501 |
| S3a `d7b286f5` | `20263905000000_round3828_service_only_money_rpc_grants.sql` | Nine service-only definer functions (payment webhooks, AMC credit, payout worker, reaper, escrow release) were executable by anon and authenticated, because migrations only revoked from PUBLIC while default privileges grant anon and authenticated directly. Anyone could forge paid or refunded escrow and read engineers' bank details | `service_only_money_rpc_grants.test.mjs`: new **9/9**, controls **5/5**. On the old grants, an anonymous caller moved escrow `pending → held` and `held → refunded`. Legitimate service-role and owner paths pass **3/3** on both |

Run any suite with Node 24 (on this laptop, `ELECTRON_RUN_AS_NODE=1 "<VS Code>/Code.exe"`):

```text
EQS_PGLITE_PACKAGE=<extracted @electric-sql/pglite@0.5.8/package> node supabase/tests/<suite>.test.mjs
```

Deployment order: round3826 before round3827, because 3827 uses 3826's helper. Round3828 is independent. Refresh the regression-suite baseline on `backend/regression-suite` in the commit that applies them.

## Urgent owner actions

- **Deploy rounds 3826–3828 soon.** The repository is public, and these commit messages describe the defects they fix, including how the money functions could be abused. Until deployed, production remains exposed.
- Decide whether to change the default privileges (`ALTER DEFAULT PRIVILEGES … REVOKE EXECUTE ON FUNCTIONS FROM anon, authenticated`) so future functions start private. This changes how every new client RPC must be written.
- After deploying 3828, reconcile escrow and AMC orders whose paid or refunded state has no matching verified Razorpay event (possible past forgeries). Also check payout beneficiary ids that don't match their method row.

## Not done / next

- **Reviews:** critic and QA on S1 were stopped mid-review by the stop request. None of S1–S3a has an accepted score yet. Re-run independent critic + QA on each batch (≥ 9.5 per AGENTS.md) before any main integration.
- **Next fix (S3b):** a contact-detail disclosure in `engineer_public_profile`, plus a related job-insert gap. The details are in the private notes below, deliberately not in this public repo.
- **Remaining audit leads:** 135 raw findings, mostly unverified. Several are known items fixed only on Codex's blocked candidate (for example DS-01 timestamp parsing, RH-01/RH-03, SE-02). Others are new: org-membership self-assignment, server-side check-in enforcement, AMC visit-cap arithmetic, an AMC contract re-pointing path, webhook-first AMC credit, and a location-picker fallback coordinate. Verify each before fixing.
- **Private notes (local only, never commit):** `C:/Users/lokes/equipseva-private-audit-20260926/`. It holds `audit_raw_findings.json` (full evidence and exploit steps), `p53_survey_findings.json`, `svc_only_candidates.json`, the Codex-owned file list, the production catalog baseline and the audit workflow script. The workflow run `wf_c6c85b66-ee3` can only be resumed from the same Claude session; otherwise re-run it from the saved script.
- No Android, edge-function or web file was changed by this session's fixes. Codex-owned files were untouched.
