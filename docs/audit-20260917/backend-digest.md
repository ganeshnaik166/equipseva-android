# EquipSeva backend digest — `C:/Users/lokes/equipseva-backend-suite` (branch `backend/regression-suite` = origin/main)
Facts + verbatim quotes only. HEAD `d3a9587b test(ux): re-record Roborazzi goldens on Linux CI`.

## 1. docs/AGENTS_READ_FIRST.md — every rule
- Header: `# Agents: read this before you continue (updated 2026-09-16)`.
- Rebase rule: "`main` moved on 2026-09-16. If your branch (`codex/*`, `claudedev-*`, or anything older than `ee885deb`) was cut before that, rebase or merge `main` **before** you build on your own handoff".
- Founder's rule: "nobody takes over a workstream without first checking the progress recorded here."
- Branch rule (whole section, verbatim): "`main == ops/r1388-calendar-burndown` (fast-forwarded together). Ship via PR to `main` (CI runs there), then fast-forward `ops`. Do not push to another agent's branch."
- Roborazzi rule: any PR/push touching `app/**` runs `.github/workflows/roborazzi.yml`; "**verify fails if your change alters a pixel of a design-system component or of those screens, or adds a `@Preview` without a golden.** Intentional visual change => Actions -> `roborazzi` -> Run workflow -> `record = true` (Linux only — never commit locally rendered PNGs)."
- Design-lint ratchet: CI fails if raw `.dp`/`.sp`/`fontSize=`/`RoundedCornerShape(`/raw M3 widgets/legacy theme imports/hardcoded `Text("` counts in `features/` rise above baseline. Local: `python3 scripts/verify/design_lint.py`. "Refresh the baseline only in a commit that lowers the numbers."
- Screen->Content rule: keep the `*Screen` wrapper thin, UI in `internal <Name>Content(state, callbacks…)`; fixture tests construct `Content` directly.
- Migration/prod rule: "Do not re-apply round3822 (it is in `supabase_migrations.schema_migrations`). Rounds 3821/3823 on the Codex branch are still **unapplied**."
- Web CI: "A red `web` run is now a real regression, not 'old debt'." Pass `<DataTable<RowType> …>` (inline `columns={[…]}` with per-column param annotations breaks inference).
- `android.yml` PR trigger skips docs/web/website-only PRs; use `scripts/ci/seed-local-config.sh` instead of copy-pasted heredocs.
- Merge points with `codex/auth-integration-20260911`: resolve "keep both", then run the ratchet + `./gradlew :app:testDebugUnitTest --tests 'com.github.takahirom.roborazzi.*' --tests '*ScreenshotTest'` before pushing.
- UX program: Phase 0 (U01-U04) closed; next open round **U05** (`Theme.kt` -> Seva colour roles); source of truth `UX_UPLIFT_PLAN.md`.

### Exact table format (section "## What landed on `main` (all CI-green, all merged)")
Three pipe-delimited columns; separator row is `|---|---|---|`:
```
| what | where | why it affects you |
|---|---|---|
```
One existing row verbatim (row 8 — shortest, shows the style):
```
| `android.yml` PR trigger now skips docs/web/website-only PRs (same `paths-ignore` as push) | `.github/workflows/android.yml` | no 19-minute Android build on a docs-only PR. |
```
Appending style: col 1 opens with `**Bold title**` + em-dash detail or a backticked file/symbol; PR numbers and round ids inline (`PR #1870 (U01/U02/U04)`, `round3822`); col 3 is an imperative/consequence sentence aimed at the next agent.

## 2. docs/HANDOFF_2026-09-16_UX_PHASE0.md — CI / supabase / branch / Roborazzi
- Branch discipline: "Nothing was pushed to `main`, `ops/*`, `codex/*` or `claudedev-*` … the founder's standing instruction of 2026-09-16: work on a different branch."
- Roborazzi gate: goldens recorded **on Linux and committed by the bot** (`6ec8a095`, 107 PNGs = 80 previews + 27 screen states) via Actions -> `roborazzi` -> Run workflow -> `record = true`; "From here on the `verify` job diffs every PR/push touching `app/**` against them."
- Roborazzi gotchas (keep): `robolectricConfig` values are pasted verbatim into `@Config(...)` — without `application = android.app.Application::class` Robolectric boots the prod Application and Hilt dies on `SettingsSessionManager`; `recordRoborazziDebug`/`verifyRoborazziDebug` are lifecycle aliases and **do not take `--tests`** (workflows call `:app:testDebugUnitTest -Proborazzi.test.record=true --tests …`); verify throws on a preview with **no** golden (`CaptureResult.Added`), so a new preview => dispatch record in the same PR; preview `name` becomes part of the golden filename, keep it ASCII; `--tests` filters must be inline and single-quoted in the workflow `run:` line; "`workflow_dispatch` only works once the workflow file exists on the default branch".
- Supabase / prod: PR #1869 fixed `cron-tick-daily`, red daily since 2026-09-07 on slot `db-storage-snapshot` (SQLSTATE 57014 — `authenticator` runs `statement_timeout=8s`, sweep walks `pg_total_relation_size()` over 4,876 public tables). round3822 = `ALTER FUNCTION public.db_storage_snapshot_sweep() SET statement_timeout = '30s'`, "applied through the Management API — `supabase link --project-ref eyswaywvtartpvtoxtdr` (no DB password needed) + `supabase db query --linked -f <migration>` — and recorded in `supabase_migrations.schema_migrations` so a later `db push` skips it." Proof: `slot=db-storage-snapshot` -> `ok: true`, 4,876 rows in 13.9 s, `cron_tick_runs` id 135 green.
- PostgREST gotcha: after a migration's `NOTIFY pgrst, 'reload schema'`, "PostgREST reloads for minutes and every request fails with PGRST002 (an 8-char code the edge function's SQLSTATE filter drops, so the run shows `slot_failed` with no code and no `cron_tick_runs` row). Wait ~3 min before probing."
- CI hygiene: `android.yml` `pull_request` gained the same `paths-ignore` as `push`; `web.yml` gained the `npm test` DataTable render smoke test; web typecheck 9,734 -> 0.
- Next steps: record goldens on `main` after the U22 PR; verify the 03:00 UTC `cron-tick-daily` via `select id, slot, ok, failed_slots from public.cron_tick_runs order by id desc limit 3` (`supabase db query --linked`); Phase 1 starts at U05.

## 3. docs/RUNBOOK_FOUNDER.md — prod access, secrets, migrations, backups
- Scope: "**Audience:** Founder (Ganesh) when something needs attention or breaks at 2am." · "Last updated: 2026-06-14 · v0.4-day-3-ultra7" · flat "if X happens, do Y" list.
- Prod access = **the Supabase SQL editor + the Web Console**; no CLI/bastion procedure in this doc. Section "## 3. Founder-only emergency commands (Supabase SQL editor)" ships 5 calls: `admin_mark_engineer_payout_paid`, `approve_refund_authorization`, `admin_set_engineer_verification`, a raw `SELECT * FROM public.engineers`, `run_reconciliation_for_date(CURRENT_DATE - 1)`.
- Secrets: "## 4. Escalation contacts (kept in 1Password)" — Supabase support via dashboard -> Help "(use account-tied email)"; Razorpay `support@razorpay.com` (include `event_id` from `/webhooks`); Cashfree `support@cashfree.com` (include `payout_id`); Cashfree wallet top-up at merchant.cashfree.com. No secret names, no rotation policy, no `.env` guidance.
- Migrations policy: **none** — the runbook never mentions migrations, `db push`, or schema change process. Manual state repair is prescribed instead ("Backfill the row in Supabase SQL editor with `manual_accepted` state"; "re-queue manually via the Supabase SQL editor (`process-engineer-payouts` edge fn re-fires)").
- Backups / DR: **no backup or restore procedure exists.** Explicitly out of scope in "## 6. What this runbook does NOT cover": "**Supabase outage** — depend on SLA; cron is best-effort"; also "**Founder phone unreachable** — no fallback plan yet (TODO: backup founder)".
- Forensic rule: on a large reconciliation anomaly — "If large: STOP. File for forensic review. The anomaly is the audit trail — do NOT delete the row."
- Closing pattern rule: "every entry should be one paragraph + one fix. If it's longer, it's not a runbook entry — it's a feature".

## 4. CONTRIBUTING.md — all rules
Architecture: (1) `features/*` may depend on `core/*` and `designsystem/*` — **never on each other**; cross-feature flows go via `navigation/Routes.kt` + `MainNavGraph.kt` and a `DeepLinkRouter.Event`. (2) "**No Java.** Kotlin 2.x throughout." (3) "**Hilt-injected repositories own all Supabase / network calls.** Compose / ViewModels do not import `supabase-kt` directly." (4) `StateFlow` for UI state, `SharedFlow(replay = 0)` for effects; Channels only for outbox/typing.

Test-pinning convention (the core rule, verbatim): "Any non-trivial gate, formatter, classifier, or copy assembler gets lifted into a top-level `internal fun` and pinned by a JUnit test that exercises the regression target."
- Lift inline `@Composable` privates to top-level `internal fun` once logic exceeds rendering; the Compose fn stays a thin wrapper.
- Lift suspend-ViewModel guards into pure helpers with explicit policy names.
- "**Pin the why, not just the what.**" A KDoc explaining why a trailing dot would be wrong beats a bare assertEquals.
- "What's worth pinning" table categories: Server CHECK mirror · Trust-and-Safety gate · Locale stability · Unicode glyph · Cross-surface invariant · Role-aware copy · Wire-frozen literal · Razorpay vocabulary.
- Test naming: one test method per behaviour, e.g. `` `zero amount invalid (server CHECK enforces positive)` ``; avoid backtick-illegal chars `>`, `<`, `..`, parens-with-periods — "silent compile failures on Kotlin test method names".
- "Outbox handler asymmetry — DO NOT UNIFY": `chatMessageSenderMismatchReason` STRICT, `notificationReadOwnerGateReason` LENIENT, `repairBidEngineerGateReason` LENIENT, `jobStatusActorGateReason` STRICT.

Code style (comment rules, verbatim):
- "**No comments that just describe what the code does.** Comments explain *why* — a hidden constraint, a past incident the code is guarding against, a subtle invariant. Identifiers should already say what."
- "**Never reference the current task / PR / fix in code comments.** Things like 'added for feature X' or 'fixes #234' rot — those belong in PR descriptions and git commit messages. Comments should make sense to a developer 18 months from now with no PR context."
- `internal fun` over `private fun` when a helper may be worth testing; Modifier-first optional on composables (lint `ModifierParameter`); "**No `@VisibleForTesting`**".

Commit / PR conventions:
- Prefixes: `test:` (new test/helper-pin), `fix:`, `feat:`, `chore:`, `refactor:`, `docs:`, `ci:`.
- "Commit messages explain *why* in the body, not just the file list — git diff covers what changed."
- "Each commit should leave the tree green (tests + lint)." Red CI blocks merge.
- Stacked PRs named `r1`, `r2`, `r3` (round N of an effort) as the chain marker, each building on the prior.

Verification before pushing (exact three): `./gradlew :app:testDebugUnitTest` (2,400+ tests) · `./gradlew :app:lintDebug` (0 errors gate) · `./gradlew :app:assembleRelease` (R8 shrink + obfuscate must succeed). "Don't push if any of the three failed locally."
Deferred: Dependabot weekly grouped minor/patch. Held back (open a tracked spike, NOT Dependabot): AGP + KSP majors, `googleid` 1.1.1 -> newer, `targetSdk = 35` -> 36.
**No migration conventions in CONTRIBUTING.md** — it never mentions SQL, `supabase/migrations`, or `db push`; migration house style lives only in the migration files themselves (section 6).

## 5. supabase/config.toml (31 lines, complete)
- Purpose comment: "Most settings are managed via the Supabase dashboard; this file's only purpose right now is to control edge-fn JWT-verification per function."
- `project_id = "eyswaywvtartpvtoxtdr"` (matches `supabase link --project-ref` in the handoff).
- **No `[db]` block => no `major_version`, no port. No `[api]`, `[auth]`, `[storage]`, `[studio]`, `[analytics]`, `[inbucket]`. No seed settings (`[db.seed]` / `sql_paths`) and no `supabase/seed.sql` on disk. No extension declarations.** Consequence: `supabase start` / `supabase db reset` run on pure CLI defaults (default PG major, no seeding, no extension preloading) and do NOT reproduce prod. Prod major version appears only in a migration comment (round3815): "UNIQUE NULLS NOT DISTINCT (PG 15+; prod is 17.6)". Extensions live in schema `extensions`, not `public` (round3800: "`pg_trgm` IS installed, but in schema `extensions`").
- Only content is five `verify_jwt = false` overrides: `[functions.razorpay-webhook]` and `[functions.payouts-webhook]` (HMAC-verified in-fn; payouts-webhook "was disabled at deploy time via `--no-verify-jwt`; pin it here so future deploys keep the setting"), plus `[functions.dispatch_repair_invoice]`, `[functions.founder_invoice_digest]`, `[functions.ingest_openfda]` ("Trigger-fired dispatchers (called via pg_net from inside the project, but the URL itself is hit with a header secret — same JWT-off pattern)").
- Siblings: `supabase/preflight_check_text_constraints_round281_292.sql` and `…_round307.sql` (ad-hoc preflight scripts outside `migrations/`). `supabase/migrations/` holds 3,376 `.sql` files; `supabase/functions/` holds 21 edge functions (incl. `cron-tick`, `_shared`).

## 6. House style — the 12 newest migrations (checklist, one verbatim example each)
Files (filename sort, oldest->newest): `20263887…round3800_auth_email_cast_and_pg_trgm` (340 L) · `20263888…round3801_order_by_out_param_class_completed` (7,635 L) · `20263889…round3802_verify_round3801_ordering` (435) · `20263890…round3803_order_by_class_closed` (266) · `20263891…round3806_engineers_verification_timestamp` (365) · `20263892…round3808_repoint_proxy_readers` (379) · `20263893…round3813_cron_tick_runs` (131) · `20263894…round3814_dsr_equipment_serial` (274) · `20263895…round3815_pm_schedule_null_serial_dupes` (120) · `20263896…round3818_attendance_65b_ledger_link` (411) · `20263897…round3819_dsr_signatures_65b_ledger` (398) · `20263899…round3822_storage_snapshot_timeout` (86). Timestamps are synthetic/monotonic (`2026388x000000`); one migration per "round N".

1. **Header banner = purpose, not rollback.** Fixed shape: `-- ====` rule, `-- Round NNNN -- <lowercase claim>`, `-- ====`, then CAPS-labelled prose blocks (`WHY:` / `FOUND BY:` / `THE GAP:` / `WHAT THIS DOES` / `THE FIX` / `WHAT THIS DELIBERATELY DOES NOT DO` / `FLAGGED, NOT CHANGED` / `VERIFICATION`). Example (round3815, lines 1-5):
   ```sql
   -- =====================================================================
   -- Round 3815 -- equipment_pm_schedule grew a duplicate row on EVERY
   --               recompute for equipment booked without a serial
   -- =====================================================================
   ```
   **There is NO rollback-SQL section — not in these 12, and no `-- ROLLBACK` / "rollback plan" header exists anywhere in the 3,376 migrations.** Reversibility is expressed two other ways: (a) whole-file atomicity via BEGIN/COMMIT, (b) an explicit re-apply contract, e.g. round3822 lines 5-7: `-- The body and access contract are pinned because this is a configuration-only change. Unknown source or settings require review instead of being replaced. -- Reapplication accepts only the original state or this migration's own state.`
2. **`BEGIN;` … `COMMIT;` wraps the whole file** — DDL plus gate — so a failed gate rolls back the schema change. All 12 do it (`BEGIN;` at line 39/49/64/67/70/73/90/102; `COMMIT;` is the last statement). Round3822 hardens further on the next line: `SET LOCAL search_path = pg_catalog, pg_temp;`
3. **`SECURITY DEFINER` + `SET search_path` form.** Two spellings, both always paired with an in-body authz check. plpgsql / `RETURNS TABLE` style (round3813):
   ```sql
   LANGUAGE plpgsql
   STABLE
   SECURITY DEFINER
   SET search_path TO 'public', 'pg_temp'
   ```
   SQL-body / helper style (round3814/3818/3819): `SET search_path = public, pg_temp`. Extension calls must still be schema-qualified (round3800: `extensions.similarity(...)`, "the FOURTH extension caught by the same trap").
4. **REVOKE/GRANT pattern + anon default-ACL handling.** Always revoke-then-grant, never a bare GRANT; `PUBLIC, anon` always in the revoke list. Function (round3813):
   ```sql
   REVOKE ALL ON FUNCTION public.founder_cron_tick_recent(integer) FROM PUBLIC, anon;
   GRANT EXECUTE ON FUNCTION public.founder_cron_tick_recent(integer) TO authenticated, service_role;
   ```
   Internal-only helper (round3818): `-- Internal-only helper: not a client RPC.` + `REVOKE EXECUTE ON FUNCTION … FROM PUBLIC, anon, authenticated;`
   New table (round3813) — the anon default-ACL rule stated explicitly: `-- Supabase default privileges would otherwise hand anon/authenticated table grants on creation (the round3791 lesson applies to tables too).` then `REVOKE ALL ON public.cron_tick_runs FROM PUBLIC, anon, authenticated;` / `GRANT SELECT, INSERT ON public.cron_tick_runs TO service_role;` / `GRANT USAGE, SELECT ON SEQUENCE public.cron_tick_runs_id_seq TO service_role;` / `GRANT SELECT ON public.cron_tick_runs TO authenticated;   -- gated by the policy below`.
   Signature change => capture and replay the ACL (round3814): `CREATE TEMP TABLE _r3814_acl ON COMMIT DROP AS SELECT p.proname, a.grantee::regrole::text AS grantee, a.privilege_type AS priv FROM pg_proc p CROSS JOIN LATERAL aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a … AND a.grantee <> 0;   -- 0 = PUBLIC; we never want that replayed` -> `DROP FUNCTION` (a DEFAULTed param added via CREATE OR REPLACE would make a second overload and PostgREST would answer PGRST203) -> `REVOKE ALL … FROM PUBLIC, anon, authenticated, service_role;` -> `DO $regrant$` replaying only captured grants -> gate asserts "the result is identical in both directions and that nothing is anon-executable".
5. **Precondition gates that RAISE on drift.** Strongest form (round3822) md5s the existing body and asserts the whole proc contract before touching it, raising `55000` with a machine-readable `DETAIL`:
   ```sql
   IF pg_catalog.md5(pg_catalog.replace(v_proc.prosrc, E'\r\n', E'\n'))
        IS DISTINCT FROM '22986e7aaaa90b1df353c5b582530840' THEN
     RAISE EXCEPTION 'storage_snapshot_timeout_precondition_failed'
       USING ERRCODE = '55000', DETAIL = 'unexpected_function_body';
   END IF;
   ```
   Its six `55000` raises cover `missing_function`, `unexpected_function_body`, `unexpected_function_contract`, `unexpected_function_settings`, `unexpected_function_access`, plus a post-condition `storage_snapshot_timeout_postcondition_failed` / `unexpected_metadata_change`. Cheaper variant = "nothing proven" floors (round3815): `IF v_before < 1 THEN RAISE EXCEPTION 'r3815 gate: equipment_pm_schedule is empty -- nothing proven'; END IF;`
   **Error codes actually used across these 12:** `42501` insufficient_privilege (authz guards + guard-rejection probes; dominant — 32 uses in round3801, also 3800/3803/3806/3808/3813/3814) · `02000` no_data (`repair_job_not_found`, `no_accepted_engineer` — 3808, 3814) · `22023` invalid_parameter_value (3814) · `55000` (3822 only) · bare `P0001` (un-coded `RAISE EXCEPTION`) for every gate failure and rollback sentinel. Canonical authz line (round3813): `IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;`
6. **Verification DO blocks with rollback sentinels.** Named dollar-quote tags (`DO $gate$`, `DO $migration$`, `DO $regrant$`) under a banner:
   ```sql
   -- ---------------------------------------------------------------------
   -- VERIFY (inside the transaction; a write probe that is rolled back)
   -- ---------------------------------------------------------------------
   ```
   Sentinel idiom — a nested `BEGIN … EXCEPTION` sub-transaction aborted by a uniquely named error, re-raising anything else (round3813, lines 121-126):
   ```sql
       RAISE EXCEPTION 'R3813_PROBE_ROLLBACK';
     EXCEPTION WHEN SQLSTATE 'P0001' THEN
       IF SQLERRM <> 'R3813_PROBE_ROLLBACK' THEN RAISE; END IF;
     END;
     SELECT count(*) INTO v_n FROM public.cron_tick_runs WHERE slot='probe';
     IF v_n <> 0 THEN RAISE EXCEPTION 'round 3813 VERIFY FAILED: probe row leaked'; END IF;
   ```
   Sentinel names in use: `R3806_PROBE_ROLLBACK`, `R3808_PROBE_ROLLBACK`, `R3813_PROBE_ROLLBACK`, `R3814_PROBE_ROLLBACK`, `ROUND3818_PROBE_ROLLBACK`, `ROUND3819_PROBE_ROLLBACK`. Role impersonation inside a gate is transaction-local: `PERFORM set_config('request.jwt.claims', json_build_object('sub','756a3373-1077-470e-bc0a-79b8d6673ef4','role','authenticated','email','ganesh1431.dhanavath@gmail.com')::text, true);` (or `'{"role":"service_role"}'`). Failure text is always `'round NNNN VERIFY FAILED: …'` (or `'rNNNN gate: …'`); success is `RAISE NOTICE 'round NNNN verified: …'`.
   **Hard rules the gates encode** (round3802's lesson, cited by 3803/3806/3808/3815): no blanket `EXCEPTION WHEN OTHERS` in a verification loop — "an EXCEPTION handler inside a verification loop can silently convert 'could not check' into 'checked and fine'. A gate that can skip everything MUST fail when it proves nothing." Gates must EXECUTE the repaired path (round3793) and assert values, not the absence of errors; where live data cannot settle it, add an unconditional static assertion (round3803 asserts exactly-one definition + `AS <col>` present + `ORDER BY … <col>` still present, then `IF v_static <> 3 THEN RAISE EXCEPTION 'round 3803 VERIFY FAILED: only % of 3 alias assertions ran'`). Round3815 proves idempotence by running the real function twice and comparing row counts.
7. **`COMMENT ON` usage** — on every new table and every new function, prefixed with the round and naming the contract. Table (round3813): `COMMENT ON TABLE public.cron_tick_runs IS 'round3813: one row per cron-tick edge-function invocation (the pg_cron substitute). Written best-effort by the function with service_role; founder-readable. Query failed_slots/results.error_code to diagnose a red scheduled run without GitHub access.';` Function (round3819): `COMMENT ON FUNCTION public.dsr_engineer_attestation_record(public.dsr_reports, text) IS 'Round 3819 — canonical §65B record of what the engineer attested in a DSR. jsonb::text is hashed into evidence_ledger.content_sha256 (kind signature_engineer) and stored as metadata.';` Column form also used: `COMMENT ON COLUMN public.engineers.verification_status_updated_at IS …` (round3806).
8. **Extras seen in the same 12:** `NOTIFY pgrst, 'reload schema';` just before `COMMIT` when a signature/contract changes (round3822, with the caveat "A notification alone is not readiness evidence"); `CREATE TABLE IF NOT EXISTS` + `CREATE INDEX IF NOT EXISTS` + `ALTER TABLE … ENABLE ROW LEVEL SECURITY` + `DROP POLICY IF EXISTS` before `CREATE POLICY` (round3813); the casting rule from round3800: "**any RETURNS TABLE column fed from auth.users.email must be cast**" (auth.users.email is `varchar(255)`; declared `text` -> 42804).

## 7. .github/workflows/secret-scan.yml and web.yml
- **Supabase CLI: not used in either file, and a grep over all 11 workflows finds no `supabase/setup-cli`, `supabase db`, `supabase link`, `npx supabase`, `supabase start`, or `db reset` anywhere.** Supabase is reached only over REST/HTTP (`supabase-keepalive.yml`, `cron-tick-*.yml`); migrations are applied by a human running `supabase db query --linked` locally (per the handoff).
- `secret-scan.yml` (36 L): `on: pull_request` + `push: branches: [main, "ops/**"]`. Permissions block, verbatim:
  ```yaml
  permissions:
    contents: read
    pull-requests: write
  ```
  Job `gitleaks` on `ubuntu-latest`: `actions/checkout@v7` with `fetch-depth: 0` ("Full history so gitleaks can scan prior commits on PRs"), then `gitleaks/gitleaks-action@v3` with env `GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}`, `GITLEAKS_ENABLE_COMMENTS: "true"`, `GITLEAKS_ENABLE_SUMMARY: "true"`. Secrets are documented as a comment on the env block, not a header: "Fail the job on any finding. No license required for public repos; if this repo becomes private, set GITLEAKS_LICENSE in repo secrets." The top-of-file comment documents only the trigger fix: "Round 3768 — was `[main]` only… Secret scanning had never once run on the active ops/* branch's pushes".
- `web.yml` (67 L): `pull_request` + `push: branches: [main, "ops/**"]`, both gated on `paths: web/**` and `.github/workflows/web.yml`. `permissions: contents: read` (only). `concurrency: group: web-${{ github.workflow }}-${{ github.ref }}` with `cancel-in-progress: true`. Job `build` ("build + typecheck"), `defaults.run.working-directory: web`; steps: `actions/checkout@v7` -> `actions/setup-node@v7` (`node-version: "20"`, `cache: "npm"`, `cache-dependency-path: web/package-lock.json`) -> `npm ci` -> `npm run typecheck` -> `npm test` (comment: "the bug this guards against was ~125 pages rendering '—' in every cell") -> `npm run build`.
  Required secrets are **not** listed at the top; the build step hardcodes placeholders with an inline rationale: `NEXT_PUBLIC_SUPABASE_URL: https://placeholder.supabase.co`, `NEXT_PUBLIC_SUPABASE_ANON_KEY: placeholder`, `NEXT_PUBLIC_FOUNDER_EMAIL: placeholder@example.com` — "Use placeholders so the build doesn't fail when GitHub Secrets aren't configured. The production deploy pipeline (Vercel) injects real values."
- House style for documenting required secrets, for comparison (`supabase-keepalive.yml` header block): `# Required secrets:` / `#   SUPABASE_URL       e.g. https://xxxxxxxxxxxx.supabase.co` / `#   SUPABASE_ANON_KEY  the publishable anon key (same one that ships in the APK)`.
- Other workflows' `permissions:` — `android.yml`, `cron-tick-code-red.yml`, `roborazzi.yml` (job-level `contents: write` on the record job only): `contents: read`; `engineer-payouts-worker.yml`: `contents: read` + `issues: write` (with the note "A watchdog that cannot bark is worse than none" and "scheduled runs execute the copy of this file on the DEFAULT branch, so this grant takes effect only when" merged); `release-aab.yml`: `contents: write`.
