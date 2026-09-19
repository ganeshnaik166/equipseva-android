# SQL / Edge / CI / Evidence-contract audit — frozen snapshot 9a0ecf89

Scope read: the 10 newest `supabase/migrations/*` (round3806 → round3823, all read in full), every `.ts` under `supabase/functions/`, `scripts/` (shell + SQL + cron summary read in full; Python/JS tooling swept), `.github/workflows/cron-tick*.yml` + `engineer-payouts-worker.yml`, and the Android r3820 evidence path (`EvidenceRegister*`, `PhotoUpload*`, `OutboxErrorClassifier`, `StorageRepository`, `RepairJobDetailViewModel` path builders). Read-only; no DB/CLI/build executed. All paths relative to `C:/Users/lokes/equipseva-audit-snap`.

Both migration md5 pins were recomputed locally (CRLF→LF normalised) and MATCH: `register_evidence` body = `f615f86834111686c7d089ca82db0990` (round3823 gate), `db_storage_snapshot_sweep` body = `22986e7aaaa90b1df353c5b582530840` (round3822 gate).

---

### SE-01 [HIGH] round3822's function-level `SET statement_timeout='30s'` cannot extend the in-flight RPC statement — the daily `db-storage-snapshot` slot will keep cancelling at 8 s
- File: supabase/migrations/20263899000000_round3822_storage_snapshot_timeout.sql:66 (gate :43-49, :70-77); supabase/functions/cron-tick/index.ts:319-323; supabase/migrations/20260860000000_round601_storage_snapshots.sql:38-67
- What: Postgres arms `STATEMENT_TIMEOUT` once, at top-level statement start (`start_xact_command → enable_statement_timeout`), from the GUC value in force at that moment — here the 8 s PostgREST applies for the impersonated `service_role` before the RPC statement runs. A function `SET` clause changes the GUC mid-statement; `statement_timeout` has no assign hook that re-arms the timer, and SPI sub-statements inside plpgsql never start a new top-level statement. The migration's "gate" only inspects `pg_proc.proconfig`, i.e. it proves the setting is stored, not that the deadline moved — exactly the "gate that proves nothing" trap.
- Evidence: `ALTER FUNCTION public.db_storage_snapshot_sweep() SET statement_timeout = '30s';` (line 66) vs. the caller `admin.rpc("db_storage_snapshot_sweep")` running through PostgREST under the same role budget that produced the recorded failure ("57014 at 8.4 s, 4,876 tables"); the body does `pg_total_relation_size(c.oid)` for every `public` relation (one filesystem stat per fork/index/toast) plus a DELETE — unchanged.
- Fix: make the sweep incremental and cheap: `db_storage_snapshot_sweep(p_after_oid oid DEFAULT 0, p_limit int DEFAULT 1500) RETURNS TABLE(inserted int, next_oid oid)` iterating `pg_class` by OID, and have the cron-tick slot loop until `next_oid IS NULL` (each call well under 8 s); or switch to catalog estimates (`relpages * current_setting('block_size')::int`) which need no stat calls. Drop the misleading function-level SET.
- Test: (1) mechanism probe through PostgREST as `service_role`: a throwaway function `SET statement_timeout='30s'` whose body is `PERFORM pg_sleep(10)` must still fail 57014 at ~8 s; (2) gate on the chunked sweep: with `pg_class` at prod size each call `< 5 s`; (3) post-deploy assert `cron_tick_runs.results` has `db-storage-snapshot ok=true`.
- Owner: ME

### SE-02 [HIGH] process-engineer-payouts asks `record_engineer_payout_dispatch` for `p_status='queued'`, which the RPC rejects (22023) — and every dispatch-record RPC result is discarded, so money-state write failures are silent
- File: supabase/functions/process-engineer-payouts/index.ts:394-400 (also unchecked at :235-239, :259-262, :367-373, :402-407, :410-416); supabase/migrations/20260713100000_round424_engineer_payouts_worker_rpcs.sql:135-137
- What: The round-466 "Cashfree 5xx → flip back to queued and retry next tick" branch calls the RPC with `p_status: "queued"`. The only definition of the RPC in the tree does `IF p_status NOT IN ('processing','failed','no_method') THEN RAISE EXCEPTION 'invalid dispatch status %' USING ERRCODE='22023'`. The worker never reads `error` from any `record_engineer_payout_dispatch` call, so the row silently stays `processing` with no `failure_reason`; it is only rescued by the hourly reaper after 30 min, and each such cycle consumes one of the reaper's 5 `attempts_count` toward dead-letter `failed`. The same blindness means a transient failure of the `processing` record after a successful `requestTransfer` leaves `razorpay_payout_id` NULL, and the eventual `TRANSFER_SUCCESS` webhook cannot match the row (money moved, DB stuck). Dormant today (Cashfree has never authed) but it is the first-real-payout path.
- Evidence: `await admin.rpc("record_engineer_payout_dispatch", { p_payout_id: row.payout_id, p_status: "queued", ... })` (index.ts:394) vs. `IF p_status NOT IN ('processing','failed','no_method')` (round424:135).
- Fix: extend the RPC to accept `'queued'` (set `status='queued'`, keep `razorpay_payout_id`, record `failure_reason`, do not double-bump `attempts`); in the worker check `error` on every dispatch-record call, log a stable code, include it in `results`, and return 500 so the round-466 canary fires when a state write fails.
- Test: SQL gate — `SELECT record_engineer_payout_dispatch(<probe>, 'queued', p_failure_reason:='x')` leaves `status='queued'` and the reason set; Deno unit test with a fake client whose `rpc` returns `{error:{code:'22023'}}` — the worker must surface `dispatch_record_failed` and exit non-2xx.
- Owner: ME

### SE-03 [MEDIUM] process-engineer-payouts' auth-failure requeue nulls `razorpay_payout_id`, undoing round 466's "keep the referenceId on requeue" — a late TRANSFER_SUCCESS can no longer match
- File: supabase/functions/process-engineer-payouts/index.ts:192-200; supabase/migrations/20260721200000_round466_payout_reconciliation.sql (`requeue_stuck_engineer_payouts` keeps `razorpay_payout_id`; `record_engineer_payout_webhook` matches `WHERE razorpay_payout_id = p_razorpay_payout_id`)
- What: Interleaving: dispatch → `processing` with referenceId R, webhook delayed → reaper requeues keeping R → next tick picks the row → Cashfree auth fails → this branch writes `{ status:'queued', razorpay_payout_id:null, razorpayx_status:null }` → `TRANSFER_SUCCESS(R)` arrives and finds no row → orphan; the row keeps cycling and is dead-lettered `failed` while the money has moved.
- Evidence: `.update({ status: "queued", razorpay_payout_id: null, razorpayx_status: null })` (index.ts:195-199) vs. the reaper's comment "Round 466: KEEP razorpay_payout_id on requeue".
- Fix: remove `razorpay_payout_id: null` from that update (mirror the reaper: only `status` + `razorpayx_status`).
- Test: unit test asserting the requeue payload has no `razorpay_payout_id` key; SQL gate replaying a webhook for a row that went through the auth-failure requeue still matches and flips to `processed`.
- Owner: ME

### SE-04 [MEDIUM] round3823 `finalize_repair_photo` has zero callers; the client still does the lossy client-side read-modify-write plus a separate `register_evidence`, so under round3821 a swallowed append failure becomes a permanent 403 GiveUp (photo stored, not attached, no ledger row)
- File: supabase/migrations/20263900000000_round3823_finalize_repair_photo.sql:1-3, 52-62; app/src/main/kotlin/com/equipseva/app/core/sync/handlers/PhotoUploadOutboxHandler.kt:125-145, 169-217; app/src/main/kotlin/com/equipseva/app/core/sync/handlers/EvidenceRegisterOutboxHandler.kt:67-89; app/src/main/kotlin/com/equipseva/app/core/sync/OutboxErrorClassifier.kt:44-46; supabase/migrations/20263898000000_round3821_evidence_authorization.sql:94-101
- What: The migration header states the problem it fixes ("client-side array replacement can lose concurrent uploads … a separate registration request can leave an attached photo without a durable evidence record"), but `grep finalize_repair_photo app/ web/ supabase/functions/` is empty. `appendUrlToContext` still swallows every failure ("Deliberately swallow"), and round3821 now raises `evidence_photo_not_attached` (42501 → HTTP 403) when the path is not in `before_photos`/`after_photos`; the classifier maps 4xx to GiveUp, so the ledger row is never written and only CrashReporter hears about it.
- Evidence: `RAISE EXCEPTION 'evidence_photo_not_attached' USING ERRCODE = '42501'` (round3821:100) vs. `Log.w(TAG, "Append-URL failed …")` swallow (PhotoUploadOutboxHandler.kt:215) followed by `outbox.enqueue(EVIDENCE_REGISTER, …)` (:140).
- Fix: replace the RMW + evidence enqueue with a single outbox step calling `finalize_repair_photo(p_job_id, p_evidence_kind, p_storage_url, p_content_sha256, p_content_size_bytes, p_captured_at, p_platform_version, p_metadata)` (idempotent, so the existing retry semantics hold); until then, treat a 403 whose message is `evidence_photo_not_attached` as Retry-after-re-append instead of GiveUp.
- Test: Robolectric test asserting the evidence handler's RPC name is `finalize_repair_photo`; server gate: one call leaves `before_photos @> ARRAY[path]` and a ledger row in the same transaction, and two concurrent finalizes for different photos keep both paths.
- Owner: ME

### SE-05 [MEDIUM] verify-play-integrity never checks `requestDetails.nonce` or `timestampMillis` — a single valid token is replayable by any account, indefinitely
- File: supabase/functions/verify-play-integrity/index.ts:43-63, 314-333; app/src/main/kotlin/com/equipseva/app/core/security/PlayIntegrityClient.kt:135-140
- What: The decoded payload's `nonce`/`timestampMillis` are typed but never compared; `pass` depends only on the verdict strings and package name. The Android client generates a random per-call nonce and its own comment admits "The server doesn't pin the nonce today". A rooted/patched install can post one token captured from a clean device under its own JWT and receive `pass:true` (and a `pass=true` audit row) forever.
- Evidence: `device = payload.deviceIntegrity?.deviceRecognitionVerdict; app = …; licensing = …;` (index.ts:324-326) with no read of `payload.requestDetails.nonce` or `.timestampMillis`.
- Fix: derive the expected nonce server-side (e.g. base64url(HMAC(secret, userId|action|10-min bucket)) handed out by a `challenge` endpoint or computed on both sides), require `payload.requestDetails.nonce === expected`, reject `timestampMillis` older than 10 min, and record the nonce with a UNIQUE index in `device_integrity_checks` to refuse replays.
- Test: Deno test with a decoded fixture: stale `timestampMillis` → 400/`pass:false`; nonce mismatch → 400; same nonce twice → 409.
- Owner: ME

### SE-06 [MEDIUM] engineer-payouts-worker.yml prints the worker's full JSON body (payout ids, Cashfree reference ids, raw Cashfree/PostgREST error text) into Actions logs every 5 minutes; the repo is public
- File: .github/workflows/engineer-payouts-worker.yml:72-80; supabase/functions/process-engineer-payouts/index.ts:172-175, 240, 249; contrast .github/workflows/cron-tick-daily.yml:56-71
- What: `curl --fail-with-body --silent --show-error …` with no `--output` writes the 200 body (`results[].reason = String(err)` / Cashfree `message`, `cashfree_reference_id`, `payout_id`) and the `pick_failed` body (`message: pickRes.error.message`, raw PostgREST detail) to stdout, i.e. to world-readable run logs. The daily workflow was hardened for exactly this ("Raw response content and curl errors must never reach Actions logs"); the payouts worker (and hourly/code-red ticks) were not.
- Evidence: `return json(500, { ok: false, code: "pick_failed", message: pickRes.error.message });` (index.ts:174) and `results.push({ payout_id, outcome: "failed", reason: String(err) })` (:240) rendered by the unredirected curl.
- Fix: mirror cron-tick-daily (`--output "$RUNNER_TEMP/…"`, print only `%{http_code}`), and stop echoing `error.message`/raw `reason` in response bodies — stable codes only.
- Test: workflow lint asserting every `curl` in `.github/workflows` has `--output`/`-o`; unit test that the worker's 200/500 bodies contain no free-text provider or PostgREST messages.
- Owner: ME

### SE-07 [MEDIUM] payouts-webhook parses Cashfree Payouts V1 field names but authenticates with the V2 header scheme — under either real webhook format every event is acked and dropped
- File: supabase/functions/payouts-webhook/index.ts:83-107 (V2 `x-webhook-signature`/`x-webhook-timestamp`, HMAC over `ts + rawBody`), 109-146 (V1 shape: `event`, `data.referenceId`, `data.utr`, `data.transferMode`), 128-131 and 142-146 (200 "ignored")
- What: The dispatch side uses the Payouts V1 API (`/payout/v1/authorize`, `/requestTransfer`), whose webhooks are form-encoded with a `signature` field computed over sorted parameter values — no `x-webhook-timestamp` header, so this handler returns 401 `bad_timestamp` before parsing. A V2-format webhook passes the signature but carries `type`/`data.transfer_id`/`data.cf_transfer_id`/`data.transfer_utr`, so `data.referenceId` is undefined → 200 `ignored: no_reference_id`, and Cashfree stops retrying. Either way transfers never flip to `processed`; rows cycle through the reaper and dead-letter `failed` while the money has moved. Caveat: exact current Cashfree formats must be confirmed against a captured sandbox event (not verifiable offline) — the V1-body/V2-signature mix in the code is internally inconsistent regardless.
- Evidence: `const expected = await hmacSha256Base64(webhookSecret, ts + raw)` (:104) alongside `const refId = data.referenceId != null ? String(data.referenceId) : null` (:128).
- Fix: commit to one version. V2: parse `type`, `data.transfer_id`, `data.cf_transfer_id` (→ `razorpay_payout_id`), `data.status`, `data.transfer_utr`, `data.transfer_mode`. V1: verify the form `signature` over concatenated sorted values with the client secret. Return 4xx, not 200, for an unrecognised shape so misconfiguration is visible instead of silently acked.
- Test: replay a recorded sandbox `TRANSFER_SUCCESS` fixture → `record_engineer_payout_webhook` called with the stored referenceId and the row flips to `processed`; unrecognised-shape fixture → non-2xx.
- Owner: ME

### SE-08 [MEDIUM] submit_dsr (round3814) lets the engineer DELETE+INSERT over a hospital-countersigned report — no status guard, no job lock
- File: supabase/migrations/20263894000000_round3814_dsr_equipment_serial.sql:90-137 (DELETE at :117); supabase/migrations/20260813000000_round494_dsr_and_nabh_bundle.sql (`hospital_sign_dsr`: `IF v_row.status <> 'pending_hospital_sign' THEN RAISE`)
- What: `hospital_sign_dsr` refuses to sign anything not pending, but `submit_dsr` never checks the existing row's status: after the hospital has signed, the engineer can unilaterally replace content and serial attestation, destroying the countersign that `nabh_bundle_for_equipment`/`dsr_for_job` and the PM-schedule projection read. The ledger keeps both attestations, but nothing in `dsr_reports` records that a signed version was withdrawn. Also, nothing locks the job, so two concurrent submits both DELETE and the second INSERT dies on `dsr_one_per_job` (23505 → 409) instead of replacing.
- Evidence: `DELETE FROM public.dsr_reports WHERE repair_job_id = p_repair_job_id;` immediately followed by INSERT, with `v_job` read via plain `SELECT … INTO v_job` (no `FOR UPDATE`) and no reference to the prior row's `status`.
- Fix: `SELECT … FROM public.repair_jobs WHERE id = p_repair_job_id FOR UPDATE;` then `IF EXISTS (SELECT 1 FROM dsr_reports WHERE repair_job_id = p AND status = 'signed') THEN RAISE EXCEPTION 'dsr_already_signed' USING ERRCODE='42501'`; model a post-countersign revision as a new versioned row (`supersedes_dsr_id`) rather than a delete.
- Test: gate — sign a probe DSR, call `submit_dsr` as its engineer → expect 42501; two-session concurrent submit → exactly one row, no 23505.
- Owner: ME

### SE-09 [LOW] round3818/round3819 ledger-link failures are swallowed into `RAISE NOTICE`, which nothing records in production — a broken §65B link is invisible
- File: supabase/migrations/20263896000000_round3818_attendance_65b_ledger_link.sql:235-242; supabase/migrations/20263897000000_round3819_dsr_signatures_65b_ledger.sql:200-203, 218-221
- What: Both triggers deliberately never abort the parent write (correct), but the only trace of a failure is a NOTICE; PostgREST discards notices and the default `log_min_messages` hides them, so a permission/`extensions.digest` regression would silently produce attendance rows and DSRs with NULL ledger links, and the founder summaries would merely show fewer rows.
- Evidence: `EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'log_engineer_arrival_attendance: ledger link skipped …'` — no durable write.
- Fix: inside each handler insert `(source_kind, source_id, sqlstate, sqlerrm, now())` into an `evidence_link_failures` table (or stamp `engineer_attendance.ledger_error` / `dsr_reports.ledger_error`) and surface a count in `founder_cron_tick_recent`/a daily slot.
- Test: gate that forces the inner block to fail (e.g. revoke `extensions.digest` inside a rolled-back subtransaction) and asserts the failure row exists while the attendance row still commits.
- Owner: ME

### SE-10 [LOW] register_evidence / finalize_repair_photo have no job-status guard — the assigned engineer can attach "before" photos (with client-asserted `captured_at`) to a completed or cancelled job
- File: supabase/migrations/20263898000000_round3821_evidence_authorization.sql:70-101; supabase/migrations/20263900000000_round3823_finalize_repair_photo.sql:91-144
- What: Authorization checks identity, path, object ownership and size, but never `v_job.status`; a completed job's evidence set (rendered into the service report) stays mutable by one party after the fact.
- Evidence: `SELECT * INTO v_job FROM public.repair_jobs WHERE id = p_job_id FOR UPDATE;` followed only by engineer/path/object checks.
- Fix: for `photo_before` require `v_job.status IN ('assigned','en_route','in_progress')`, for `photo_after` `IN ('in_progress','completed')` within a bounded window; reject `cancelled`; store `job_status_at_registration` in the server-owned metadata.
- Test: gate — finalize on a cancelled probe job → 42501; on an in-progress job → success.
- Owner: ME

### SE-11 [LOW] razorpay-webhook's `unhandled_event_type` audit insert is fire-and-forget (`.then()` without `await`) — the edge runtime can end the invocation before it lands
- File: supabase/functions/razorpay-webhook/index.ts:387-402
- What: The insert that is the only record of unhandled events is not awaited; the response is returned immediately.
- Evidence: `await admin.from("razorpay_webhook_events").insert({…}).select().single().then((r) => {…});` — the `await` applies to the `.then` chain only after the response has been scheduled; safer to `await` the query before `return json(200, …)`.
- Fix: `const r = await …insert(…).select().single(); if (r.error && !/duplicate/i.test(r.error.message)) console.error(…)`, then return.
- Test: unit test with a fake client that resolves the insert asynchronously; assert it resolved before the handler returned.
- Owner: ME

### SE-12 [LOW] `payment.authorized` is treated as paid (server verify + webhook) while no order is created with `payment_capture`; an authorization that never captures auto-reverses after ~5 days but the escrow/order stays held/completed
- File: supabase/functions/_shared/razorpay_server_verify.ts:148-158; supabase/functions/razorpay-webhook/index.ts:144-162; supabase/functions/create-repair-job-payment-order/index.ts:148-166; create-amc-payment-order/index.ts:181-197; create-razorpay-order/index.ts:117-127
- What: `authorized` is accepted as success on the assumption that auto-capture follows; none of the three order creators request `payment_capture: 1`, so capture depends on a dashboard setting, and there is no sweep for authorized-but-never-captured rows.
- Evidence: `if (payment.status !== "captured" && payment.status !== "authorized") { … }` (server_verify.ts:151) and `eventType === "payment.captured" || eventType === "payment.authorized"` (webhook:144).
- Fix: send `payment_capture: 1` on order creation; treat `authorized` as a distinct `authorized_pending_capture` state that only `payment.captured` upgrades; add a daily slot flagging authorized rows older than 24 h.
- Test: fixture with `status:'authorized'` → row not `held`; `payment.captured` webhook upgrades it; sweep flags a 25-hour-old authorized row.
- Owner: ME

### SE-13 [LOW] export_nabh_bundle echoes raw PostgREST/Storage `error.message` to the client
- File: supabase/functions/export_nabh_bundle/index.ts:217-224, 236-239, 295, 300-302
- What: `rate_check_failed`, `rpc_failed`, `upload_failed`, `sign_failed` return `err.message` verbatim (constraint names, RLS verdicts, storage paths) — the leak class the other functions were hardened against (rounds 269-273, 306).
- Evidence: `return bad("rpc_failed", rpcErr.message, 500);` / `if (upErr) return bad("upload_failed", upErr.message, 500);`
- Fix: log server-side, return stable codes only (keep the 429/401/403 branches, drop the message pass-through).
- Test: unit test asserting no response body contains `error.message` text for a forced RPC failure.
- Owner: ME

---

Verified-clean areas:
- **Android ↔ round3821/3823 contract**: object path is exactly `<auth uid>/<job uuid>/<filename>` (RepairJobDetailViewModel.kt:675-676, 885-886; `uid` = signed-in session userId, `job.id` = job uuid); filename sanitised to `[A-Za-z0-9._-]` so `v_parts[4] ~ '^[A-Za-z0-9._-]+$'` holds; `storageUrl = "repair-photos/" + objectPath` (EvidenceRegisterPayload.kt:74, bucket constant `StorageRepository.Buckets.REPAIR_PHOTOS = "repair-photos"`) → exactly 4 segments; the arrays store the bucket-less objectPath (PhotoUploadOutboxHandler.kt:198-207), matching `v_object_path`; kind/source/producer literals (`photo_before|photo_after`, `repair_job`, `engineer`) match the CHECKs and the round3821 allow-list; sha256/size come from the post-EXIF-scrub bytes that are the uploaded body (StorageRepository.kt:62-71) so `metadata->>'size'` matches; upload runs under the user's JWT (owner_id = uid; storage INSERT policy `foldername(name)[1] = auth.uid()`); all 10 RPC parameter names match; outbox drains sequentially so the append precedes registration; PostgREST maps 42501→403 (GiveUp), 22023/02000→400 (GiveUp), 40001→500 (Retry), consistent with the classifier.
- **md5 pins**: both recomputed and matching (see header); proconfig strings match `search_path=public, pg_temp`.
- **ACL trap**: r3813/r3814/r3818/r3819/r3821/r3823 all revoke PUBLIC/anon explicitly; r3814 captures and replays the ACL around DROP+CREATE and asserts equality both ways; r3823 asserts service_role is revoked on the client-only finalizer; r3822 gate confirms `anon`/`authenticated` cannot execute the sweep.
- **ORDER BY OUT-param trap**: every RETURNS TABLE body (r3808 ×2, r3813, r3814 `dsr_for_job`, r3821 ×2) qualifies columns with table aliases; no unqualified ORDER BY.
- **Nullable ON CONFLICT keys**: `evidence_ledger_uniq` columns are all NOT NULL; `pm_schedule_uniq` is now `UNIQUE NULLS NOT DISTINCT` (r3815) with a deduplicate + two-real-recompute gate.
- **pgcrypto under pinned search_path**: r3818/r3819 use `extensions.digest(...)`.
- **Trigger abort risk for the finalize UPDATE**: all `repair_jobs` UPDATE triggers are WHEN-gated on status/rating/payout/engineer_id/warranty changes; the two ungated BEFORE triggers (rating guard, commission) are no-ops when those columns are unchanged; `log_engineer_arrival_attendance_trg` requires a status transition.
- **Gates**: r3806/r3808/r3813/r3814/r3815/r3818/r3819 have no blanket `WHEN OTHERS … CONTINUE`; probe errors are re-raised as VERIFY FAILED; sentinel-rollback pattern is correct; r3806 ages the timestamp before testing the stamp.
- **Webhook/verify hygiene**: constant-time HMAC compares everywhere; razorpay-webhook signs the raw body and dedups on `x-razorpay-event-id`; verify-* bind `razorpay_order_id`, cross-check amount/currency/status via Razorpay GET, use TOCTOU-guarded status-filtered updates, decode identity with an anon-key client, and never log the signature.
- **cron-tick**: daily group (26 slots) equals `cron_response_summary.DAILY_SLOTS`; run persistence is best-effort and non-masking; `stableErrorCode` whitelist matches the Python regex; IST-yesterday computation is correct; `invoice-digest` secret/headers match `founder_invoice_digest`.
- **Authority model**: no migration clears or reassigns `repair_jobs.engineer_id` (only `accept_repair_bid` sets it and `repair_jobs_engineer_id_guard_trg` protects it), so `submit_dsr`/`build_pved` resolving the engineer from the accepted bid is currently equivalent to the engineer_id-based check in r3821/r3823 — noted, not a defect.
- **scripts/**: no embedded secrets (service key read from `~/.equipseva-service-role` / env; GoDaddy creds from env); shell scripts use `set -euo pipefail`; `cron_response_summary.py` fails closed on malformed bodies and never echoes response text; `orderby_recheck.sql` is self-contained.
