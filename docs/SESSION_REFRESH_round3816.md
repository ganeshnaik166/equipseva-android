# round3816–3818 — sessions that refresh, an honest check-in CTA, and the first §65B evidence

Branch `ops/r1388-calendar-burndown`. Dates 2026-09-07 (UTC).

## round3816 — app: sessions never refreshed after the 3600 s JWT lapsed

**Symptom (reproduced 3× on the emulator, 2026-09-06/07):** after ~60–75 min every RPC returned the
expired-JWT class ("Your session expired. Tap retry…"), Profile showed "Network problem", Sign out was
unreachable; only `pm clear` recovered.

**Cause:** the app pinned supabase-kt **3.0.3**, which refreshes only on a lifecycle-bound timer that
Android stops whenever another activity (photo picker, permission dialog) takes the foreground — and
never refreshes on demand.

**Fix:** upgrade to supabase-kt **3.6.0** (ktor 3.4.3, Kotlin 2.3.21; KSP 2.3.11 unchanged; 3.8.0
avoided — it needs Kotlin 2.4.0 and KSP for 2.4 is unconfirmed). 3.6.0 carries two relevant fixes:
* `checkSessionOnRequest` (default on): before any authenticated request the SDK compares the token's
  `expiresAt` with now and **force-refreshes** an expired session (`AccessToken.kt`); if that refresh
  fails it throws `TokenExpiredException` instead of sending a dead token.
* the Android `onStart` observer no longer emits a spurious `NotAuthenticated`.

**Compile fallout and what each meant**

| error | cause | fix |
|---|---|---|
| `EncryptedSessionManager.loadSession(): UserSession?` not a subtype | `SessionManager.loadSession()` is now non-null and must THROW when nothing is stored; `loadSessionOrNull()` is the SDK's catch wrapper | throw `NoSuchElementException` / `IllegalStateException` (decode failure still clears the blob first); Robolectric test pins the contract |
| `KycViewModel.kt:990 Unresolved reference 'System'` | kotlinx-datetime 0.7.x removed `kotlinx.datetime.Clock.System`; `kotlin.time.Clock` is stable since Kotlin 2.3 | `import kotlin.time.Clock` (only usage in the app) |
| tests: `RestException(statusCode=…, message=…)` no such parameters | `RestException(error, description, response: HttpResponse)` — `statusCode` and `message` derive from a real ktor response | `testing/FakeRest.kt` builds one through ktor `MockEngine` (`ktor-client-mock` test dep) |

**A production regression the broken tests exposed (fixed):** 3.x's `RestException.message` ALWAYS ends
with `URL: … / Headers: … / Http Method: …`. `DataError.friendlyRestMessage` joined message + description +
error and then asked `looksLikeRawDbError()` — which keys on `"URL:"` — before passing an unmapped
human server message through. Under 3.6.0 that would have collapsed EVERY unmapped `RAISE` message
(e.g. `Phone number required to accept jobs.`) into the generic fallback. The pass-through now judges
the PostgREST body (`description`, else `error`) alone; keyword matchers still see the joined string.
`TokenExpiredException` (not a `RestException`) now maps to the same session-expired copy as PGRST301.

**Log-level gotcha (found during the idle test, reverted in r3820):** `cb9142af` set the SDK to
`LogLevel.DEBUG` in debug builds to watch the refresh mechanism. At DEBUG supabase-kt prints the FULL
`UserSession` — access token AND refresh token — in its "Importing session …" / "Setting session status …"
lines (only the expired-token error path masks them). A refresh token in logcat is a session-hijack
primitive, so the level is back at the SDK default (INFO) for every build type; flip it locally for an
auth investigation and flip it back. The useful DEBUG lines, for the record: `Session imported
successfully. Starting auto refresh…` and `Refreshing session in 47m 59s` (= 80 % of `expires_in`).

**Stored 3.0.3 sessions survive the upgrade:** the interim 3.6.0 APK installed over the old build
relaunched straight into the signed-in hospital session (the countersigned RPR-00040 DSR), 0 crashes.
`UserSession.expiresAt` moved from `kotlinx.datetime.Instant` to `kotlin.time.Instant`; both serialise
as ISO-8601 so the encrypted blob decodes unchanged.

**Verify bar:** `./gradlew.bat :app:testDebugUnitTest :app:lintDebug :app:assembleDebug --continue` —
green (see commit). New tests: `EncryptedSessionManagerRobolectricTest`, `IsViewerAssignedEngineerTest`,
two regression pins in `DataErrorTest`.

**On-device idle test — PASSED 2026-09-07 (emulator `eqs`, final r3816 APK, play-review-hospital):**

| UTC | event (logcat `Supabase-Auth`, debug build) |
|---|---|
| 04:50:52 | fresh sign-in; JWT `exp` 05:50:53; SDK: `Refreshing session in 47m 59s` |
| 05:38:51 | timer fired while the app sat idle in the foreground: `Session expired. Refreshing session…` → new session saved; realtime channel re-subscribed with a token whose `exp` = 06:38:56; next timer scheduled 06:26:54 |
| 06:26:54 | **scheduled refresh did NOT run** (nothing logged; the SDK's own `autoRefreshInformation` later showed `refreshingAt=06:26:54`, `lastRefreshedAt=null`, `Auto refresh running: true`) — the exact failure class behind the original bug |
| 06:37:39 | after 106 min idle: Profile + Home loaded (GET /profiles 200, RPC engineer_has_complete_payout_methods 200), no error copy |
| 06:39:04 | first request AFTER expiry: `Authenticated request attempted with expired access token … Trying to refresh session before…` → `POST /auth/v1/token` 200 in 1.56 s → engineers/profiles/RPC all 200 → screens rendered; new token `exp` 07:39:06; 0 crashes |

So both 3.6.0 mechanisms were exercised for real: the timer path once, and — because the timer then silently failed exactly as
it always had — the request-time force-refresh failsafe (`checkSessionOnRequest`) recovered the session transparently. Under
3.0.3 the 06:39 request would have been the "Your session expired" dead end that needed `pm clear`. Note: the bottom tab is
labelled **Jobs** for hospitals (the memory's "Bookings" is the screen title), which is why the first probe tap missed.

## round3817 — app: "Check in on-site" showed for ANY engineer viewing an Assigned job

`StickyBottomBar` keyed the Check-in / Mark-done / Revise-quote CTAs on bare `isEngineer && status`.
An engineer opening someone else's Assigned job saw a live check-in button and got a server 42501.
Safe, but a CTA that can only fail hides the job's real state.

Fix: `RepairJobDetailUiState.selfEngineerRowId` (the viewer's own `engineers.id`, already fetched for
role resolution) + pure `isViewerAssignedEngineer(job, selfEngineerRowId, ownBid)`: true when the
viewer's engineers row IS `job.engineerId` (the only link that exists for AMC visit jobs, which are
pre-assigned without a bid) OR the viewer's own bid on this job is Accepted (marketplace path; also the
fallback when the engineers row fetch fails). Cancel already used the bid signal; it now uses both.
Place bid, Rate and the hospital CTAs are unchanged.

## round3818 — db: GPS check-ins become §65B evidence; `engineer_attendance.evidence_ledger_id` populated

Verified before writing: `public.evidence_ledger` had **0 rows since round492** — `register_evidence`
has no caller anywhere (Kotlin, web, edge, SQL). The founder 65B summary, hospital evidence list and
certificate generator had only ever run over an empty table. The single attendance row (RPR-00040) had
a NULL ledger link.

Migration `20263896000000_round3818_attendance_65b_ledger_link.sql` (applied to prod 2026-09-07 ~04:55 UTC):
1. `evidence_kind` CHECK gains `'gps_checkin'` (live constraint name verified in `pg_constraint`).
2. `gps_checkin_evidence_record(...)` — canonical jsonb of the check-in (job, engineer, hospital, both
   coordinate pairs, distance, flag, capture time). EXECUTE revoked from PUBLIC/anon/authenticated
   (the Supabase default-ACL trap: a fresh CREATE publishes to anon).
3. `log_engineer_arrival_attendance()` (round3787's trigger fn, CREATE OR REPLACE — no ACL replay
   needed) now, after inserting the attendance row, hashes `record::text` with
   `extensions.digest(…, 'sha256')`, inserts `evidence_ledger(kind gps_checkin, source repair_job,
   producer = the engineer resolved server-side, metadata = record)` and stamps
   `engineer_attendance.evidence_ledger_id`. The ledger step has its OWN exception guard: a ledger
   failure can only lose the link, never the attendance row; the outer guard still means attendance
   logging can never abort a check-in.
4. Backfill of pre-existing arrival rows, flagged `platform_version='round3818-backfill'` with
   `captured_at = device_captured_at`, so a retro-registered record is distinguishable from one hashed
   at capture time.

Gate (ran inside the transaction, then rolled back): a real check-in-shaped UPDATE on a real assigned job
produced +1 attendance and +1 ledger row, the attendance row pointed at the ledger row, kind/source/producer
matched, and `sha256(metadata::text)` equalled `content_sha256` (474 bytes). Post-apply probe: ledger 1 row
(the backfill), sha reproducible, linked 1/1, helper not executable by anon/authenticated,
`jobs_in_progress` unchanged (probe rolled back).

`verify_evidence_hash()` and `generate_65b_certificate()` work on these rows exactly as on files
(recompute `sha256(metadata::text)`); `evidence_for_repair_job(job)` now returns the check-in for both
parties; the founder's `founder_evidence_ledger_65b_summary()` finally has a non-zero `total_evidence_rows`.

## round3819 — db: DSR engineer attestation + hospital countersign become chained §65B evidence

`dsr_reports` was designed (round494) with `engineer_signature_ledger`, `hospital_signature_ledger`,
`rendered_pdf_ledger`; both live reports (RPR-00041, RPR-00040) had all three NULL and the table had no
triggers. `submit_dsr` is DELETE+INSERT per submission (a "Revise report" is a fresh INSERT);
`hospital_sign_dsr` flips `hospital_signature_at` NULL→now.

Migration `20263897000000_round3819_dsr_signatures_65b_ledger.sql` (applied 2026-09-07 ~05:05 UTC):
* `dsr_engineer_attestation_record(dsr, job_number)` — canonical jsonb of everything the engineer attests
  (all report content + identities + `engineer_signature_at`).
* `dsr_hospital_countersign_record(dsr, job_number, attests_sha256)` — canonical jsonb of the countersign
  that **carries the sha256 of the engineer record it signs**. That is the chain: a resubmit yields a new
  engineer sha, so an old countersign visibly no longer covers the current report.
* `register_canonical_evidence(kind, job, record, producer, producer_kind, captured_at, platform)` —
  shared idempotent writer (sha256 of `record::text`, size, metadata = record).
* BEFORE INSERT OR UPDATE trigger `dsr_register_signature_evidence_trg`: INSERT → `signature_engineer`
  row, `NEW.engineer_signature_ledger` set in place; UPDATE with `hospital_signature_at` NULL→set →
  `signature_hospital` row, `NEW.hospital_signature_ledger` set in place. BEFORE (not AFTER) so there is no
  self-UPDATE and no recursion. Each branch exception-guarded: can never abort a submit or a sign.
* Backfill of the 2 signed reports (2 attestations + 2 countersigns, `round3819-backfill`,
  `captured_at` = the original signature instants). `rendered_pdf_ledger` stays NULL — there is no PDF
  renderer, and a fake "pdf" record would be compliance theatre.
* All 4 new functions revoked from PUBLIC/anon/authenticated (default-ACL trap).

Gate (rolled back): a submit-shaped INSERT on a real job with an accepted engineer and no report → engineer
evidence linked (813 bytes, hash recomputes, record describes the probed report); a countersign-shaped
UPDATE → hospital evidence linked, `attests_sha256` == the engineer row's sha, signer carried; exactly +2
ledger rows. Post-apply: ledger 5 rows, all hashes recompute, both DSR chains `chain_ok`, trigger enabled,
`evidence_for_repair_job(RPR-00040)` now returns `gps_checkin → signature_engineer → signature_hospital`.

## round3820 — app: repair before/after photos are registered as §65B evidence

Postgres cannot read Storage object bytes, so photo evidence has to be hashed on the client. The photo
upload path already funnels through `StorageRepository.upload` (MIME allowlist, size cap, EXIF scrub,
path safety) and the `photo_upload` outbox kind.

* `StorageRepository.upload` now returns `Result<UploadReceipt>` (bucket, object path, **sha256 of the
  post-scrub bytes**, size) — the stored object is what a later download returns, so that is the only hash
  `verify_evidence_hash()` can ever match. Every existing caller ignored the `Unit`; none needed changing.
  `ByteArray.sha256Hex()` (`core/util/Sha256.kt`) is pinned against the FIPS vectors and the exact digest
  the round3818 prod probe produced for "abc".
* `PhotoUploadOutboxHandler`, after a successful upload + URL append, enqueues a **new outbox kind**
  `evidence_register` (`EvidenceRegisterPayload.forUploadedPhoto`) for `repair_job_before` → `photo_before`
  and `repair_job_after` → `photo_after`. Issue photos (the hospital's booking attachments) and KYC
  documents are deliberately NOT evidence and map to nothing. Failing to *enqueue* is logged, never fails
  the upload.
* `EvidenceRegisterOutboxHandler` calls round492's `register_evidence` RPC (kind, `repair_job`, job id,
  sha, size, `bucket/path`, producer `engineer`, captured_at = upload instant — stated as such in
  metadata rather than dressed up as an EXIF time — `platform_version = android/<versionName>`). Owner
  gate mirrors the photo handler. Transient → Retry; 4xx → GiveUp **after** `CrashReporter.report` (a photo
  on the job with no ledger row is a compliance gap someone must see); a blank RPC result is treated as a
  defect, not a success.
* Why its own kind: `register_evidence` is idempotent on (kind, source, id, sha), so retrying it is free;
  re-uploading a photo to retry it is not — and a permanent registration failure must never read as
  "photo upload failed". Poison-drop copy for the new kind says the photo IS on the job.
* Also in this round: SDK log level back to INFO (see the log-level gotcha above).

Tests: `Sha256Test`, `EvidenceRegisterPayloadTest` (kind mapping incl. the KYC/issue exclusions, payload
contents, JSON round-trip), `OutboxKindsTest` + `PoisonDropCopyTest` extended.

Not yet proven on-device: an actual before-photo upload through the new path (needs a check-in drive with
the system photo picker — see the emulator memory recipe). The RPC and its grants were verified
server-side; the client path is unit-tested and bar-green.

## Still open for the §65B chain
`rendered_pdf_ledger` (no PDF renderer exists), chat archives, voice notes, parts receipts — each needs a
producer first. `generate_65b_certificate()` has no client yet.
