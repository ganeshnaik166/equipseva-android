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
Debug builds set the SDK log level to DEBUG so the refresh mechanism is visible in logcat (release
unchanged).

**Stored 3.0.3 sessions survive the upgrade:** the interim 3.6.0 APK installed over the old build
relaunched straight into the signed-in hospital session (the countersigned RPR-00040 DSR), 0 crashes.
`UserSession.expiresAt` moved from `kotlinx.datetime.Instant` to `kotlin.time.Instant`; both serialise
as ISO-8601 so the encrypted blob decodes unchanged.

**Verify bar:** `./gradlew.bat :app:testDebugUnitTest :app:lintDebug :app:assembleDebug --continue` —
green (see commit). New tests: `EncryptedSessionManagerRobolectricTest`, `IsViewerAssignedEngineerTest`,
two regression pins in `DataErrorTest`.

**On-device idle test:** see the addendum at the bottom of this file.

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

Not done here (still open): photo/DSR/signature evidence is still not registered — those kinds need a
client-side sha256 at upload time (`register_evidence` exists and is unchanged). That is the next
natural round for the §65B chain.
