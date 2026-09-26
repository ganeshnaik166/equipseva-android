# Bug audit — features/repair, hospital, mybids, activework, chat
Snapshot: C:/Users/lokes/equipseva-audit-snap @ 9a0ecf89 (read-only). 22 findings, ordered by severity. Paths relative to the snapshot root; `app/…` = `app/src/main/kotlin/com/equipseva/app/…`.

### RH-01 [HIGH] Every status-transition failure is treated as "offline": server rejections flip the local status and queue a doomed outbox row
- File: app/features/repair/RepairJobDetailViewModel.kt:983-998 (also core/data/repair/JobStatusOutboxHandler.kt:65-68, core/sync/OutboxErrorClassifier.kt:44-46)
- What: `transitionStatus.onFailure` unconditionally enqueues the transition, optimistically sets `job.status = target`, and toasts "Offline — status change will apply when back online" — for ANY throwable, including PostgREST 22023 ("invalid status transition in_progress -> cancelled"), 42501 ("only the assigned engineer can mark this job complete") or a P0002. The drain handler then `GiveUp`s on 4xx, so the row is silently dropped while the UI keeps showing Cancelled/Completed until the next reload. Hospital cancels a job the engineer already moved to in_progress → sees "Job cancelled"-looking state + an offline toast; the job is still live.
- Evidence: `onFailure = { ex -> queueStatusForRetry(...); _state.update { it.copy(updatingStatus = false, job = it.job?.copy(status = target)) }; _messages.emit("Offline — status change will apply when back online") }` vs `classifyOutboxError`: `error.statusCode in 400..499 -> GiveUp(...)`. `toUserMessage()` (core/network/DataError.kt:17) already isolates the true network class (`HttpRequestException`, `IOException`).
- Fix: branch on `ex is IOException || ex is HttpRequestException` (mirror DataError.kt): only then queue + optimistic flip + offline copy; otherwise leave `job` untouched, `updatingStatus=false`, emit `ex.toUserMessage()`.
- Test: VM unit test with a fake `RepairJobRepository.updateStatus` returning `Result.failure(RestException(422, …))` → assert `state.job.status` unchanged, `outboxEnqueuer.enqueue` never called, emitted message == `ex.toUserMessage()`; second case `IOException` → enqueue called once + optimistic flip.
- Owner: ME

### RH-02 [HIGH] Engineer-side "Cancel" CTA is a dead control (VM + server are hospital-only)
- File: app/features/repair/RepairJobDetailScreen.kt:2088-2094, 2226-2233; app/features/repair/RepairJobDetailViewModel.kt:914-920, 963-968
- What: `StickyBottomBar.canCancel` is true for `isAssignedEngineer && job.status == Assigned`, so the assigned engineer sees "Cancel", opens `CancelSheet`, types a ≥10-char reason, taps "Cancel job" — and nothing happens: `cancelJob()` calls `transitionStatus(requireHospital = true)`, which silently `return`s when `viewerRole != Hospital`. The server agrees (`repair_jobs_status_transition_guard`: "only the hospital can cancel a job", 42501), so the button can never work.
- Evidence: `isAssignedEngineer -> job.status == RepairJobStatus.Assigned` (canCancel) vs `if (requireHospital && snap.viewerRole != ViewerRole.Hospital) return`.
- Fix: `val canCancel = isHospital && job.status in setOf(Requested, Assigned)`; delete the engineer branch (or, if engineer cancellation is a real product need, add a server path first).
- Test: hoist the gate to `internal fun canCancelJob(viewerRole, isAssignedEngineer, status)` and pin `Engineer/Assigned → false`; Robolectric compose test renders `StickyBottomBar` with Engineer role + Assigned job and asserts no node with text "Cancel".
- Owner: ME

### RH-03 [HIGH] `submitBid` treats every failure as offline and queues bids the outbox will drop
- File: app/features/repair/RepairJobDetailViewModel.kt:501-506 (core/data/repair/RepairBidOutboxHandler.kt:59-62)
- What: Any `placeBid` failure (RLS 42501 for an unverified/blocked engineer, bidding on a job that just left `requested`, CHECK violation) is queued via `queueBidForRetry` and reported as "Offline — bid will submit when back online". The drain classifies the 4xx as `GiveUp`; the engineer waits for a bid that was never accepted by the server and never learns why.
- Evidence: `onFailure = { ex -> queueBidForRetry(amountRupees, etaHours, note); … _messages.emit("Offline — bid will submit when back online") }` — `ex` is never inspected.
- Fix: same network-class predicate as RH-01; for non-network failures emit `ex.toUserMessage()` and keep the composer open with the typed values.
- Test: fake `RepairBidRepository.placeBid` → `Result.failure(RestException(403,…))`: assert no `outboxEnqueuer.enqueue`, `bidComposerOpen` stays true, message == `toUserMessage()`.
- Owner: ME

### RH-04 [MEDIUM] Hospital "Message" on the Assigned-engineer card is dead for AMC pre-assigned jobs
- File: app/features/repair/RepairJobDetailViewModel.kt:573-586; app/features/repair/RepairJobDetailScreen.kt:662-678
- What: The card renders whenever `job.engineerId != null && isHospital`, but `openChatWithEngineer` resolves the counterparty ONLY from `snap.bids.firstOrNull { status == Accepted }`. AMC maintenance visits are pre-assigned without any bid (the codebase already special-cases this in `shouldShowBidsSection`), so the tap yields "No engineer assigned yet" directly under a section titled "Assigned engineer"; the name also falls back to the literal "Engineer".
- Evidence: `val engineerUserId = snap.bids.firstOrNull { it.status == RepairBidStatus.Accepted }?.engineerUserId; if (engineerUserId.isNullOrBlank()) { _messages.tryEmit("No engineer assigned yet"); return }`.
- Fix: fall back to `engineerRepository.fetchById(job.engineerId).getOrNull()?.userId` (and resolve the display name from it in `load()`); only emit the toast if both sources are empty.
- Test: VM test — job with `engineerId="e1"`, `bids = emptyList()`, fake engineer repo returning `userId="u-eng"` → expect `Effect.NavigateToChat` and `chatRepository.getOrCreateForRepairJob` called with `[self, "u-eng"]`.
- Owner: ME

### RH-05 [MEDIUM] `runCatching { photoUploadStash.enqueue(...) }` swallows enqueue failures (and CancellationException) — "Mark done" can complete with zero photos
- File: app/features/repair/RepairJobDetailViewModel.kt:668-687 (check-in), 881-899 (completion); core/sync/handlers/PhotoUploadStash.kt:88-91; core/sync/handlers/PhotoUploadPayload.kt:51
- What: `PhotoUploadStash.enqueue` throws `IllegalArgumentException` for empty bytes or >15 MB files (`MAX_FILE_SIZE_BYTES = 15 MiB`, a plausible size for a 50 MP camera JPEG) and IOException on disk-write failure. Both loops wrap it in `runCatching {}` with no result check, then `markDone()` / `checkIn()` proceed. The KDoc promises "Refuse the call with no photos", but a single oversized photo silently yields a Completed job with no after-photo evidence (48 h escrow auto-release has nothing to dispute against). `runCatching` also swallows `CancellationException` from the suspend call.
- Evidence: `photos.forEach { photo -> runCatching { … photoUploadStash.enqueue(...) } }` → `_state.update { proofSheetOpen=false, submittingProof=false }; markDone()`.
- Fix: count `enqueue` successes (`runCatching { … }.onFailure { if (it is CancellationException) throw it }.isSuccess`); if `enqueued == 0` → keep the sheet open, emit "Couldn't save the photo(s) — try a smaller photo" and do NOT transition; otherwise proceed.
- Test: fake stash whose `enqueue` throws `IllegalArgumentException` → assert `jobRepository.updateStatus` never called, `proofSheetOpen` still true, a message emitted; fake stash throwing `CancellationException` → assert it propagates.
- Owner: ME

### RH-06 [MEDIUM] Check-in double-submit window: nothing is marked in-flight until after the photo enqueue loop
- File: app/features/repair/RepairJobDetailViewModel.kt:655-690; app/features/repair/RepairJobDetailScreen.kt:2578-2605, 414-423
- What: `submitCheckinWithProof` reads `updatingStatus` but sets nothing before the suspend enqueue loop; `updatingStatus` only flips inside `checkIn()` afterwards. In `CheckinSheet` the confirm button launches an IO read of up to 4 multi-MB photos and stays enabled meanwhile (`disabled = picked.isEmpty() || updating`, `updating` false). A second tap during the read runs the whole path again → the before-photo set is stashed/uploaded twice; only the RPC is de-duplicated by `checkIn()`'s guard. `CompletionProofSheet` has the same enabled-during-read window (its VM guard is a non-atomic check-then-set from an IO thread).
- Evidence: `if (snap.updatingStatus) return … viewModelScope.launch { … photos.forEach { enqueue } ; checkIn() }` — no `_state.update` before the launch.
- Fix: `_state.update { it.copy(updatingStatus = true) }` synchronously at the top of `submitCheckinWithProof` (and reset on the early-return paths); in both sheets add a local `reading` state set before `scope.launch(IO)` and include it in `disabled`.
- Test: VM test calling `submitCheckinWithProof(photos)` twice back-to-back with a fake stash → assert `enqueue` invoked exactly `photos.size` times and `engineerCheckInWithGeo` once.
- Owner: ME

### RH-07 [MEDIUM] Disputed jobs disappear from the engineer's Active work list
- File: app/features/activework/ActiveWorkViewModel.kt:65-79
- What: Jobs are bucketed into `Assigned/EnRoute/InProgress` and `Completed/Cancelled`; `RepairJobStatus.Disputed` (server allows `completed → disputed`, and `RepairJobDetailScreen` renders a dispute banner + the engineer's "Respond to dispute" CTA) matches neither list, so the engineer loses the only list entry point to the job exactly when they must respond within the admin review window. The hospital side (`HospitalActiveJobsViewModel`) correctly includes Disputed in `closed`.
- Evidence: `val completed = jobs.filter { it.status in listOf(RepairJobStatus.Completed, RepairJobStatus.Cancelled) }`.
- Fix: add `RepairJobStatus.Disputed` to the `completed` bucket (or a dedicated bucket surfaced first).
- Test: VM unit test — `fetchAssignedToMe` returns one Disputed job → assert it appears in `completedJobs` (and `activeWorkSubtitle` counts it).
- Owner: ME

### RH-08 [MEDIUM] DSR "Revise report" silently wipes the calibration attestation
- File: app/features/repair/DsrScreen.kt:219-232, 274-283; app/features/repair/DsrRepository.kt:35-36, 98-123
- What: The revise path prefills summary, recommendations, IEC verdict and serial, but `calibrationPerformed`, `calibChoice` and `calibrationLabRef` reset to `false / -1 / ""`. `submit_dsr` REPLACES the previous row (repository KDoc), and the repository sends `p_calibration_within_oem = null` / `p_calibration_lab_ref = null` when `calibrationPerformed` is false — so an engineer who only fixes a typo in the summary downgrades the NABH record from "calibrated, within OEM tolerance" to "no calibration".
- Evidence: `DsrForm(initialSummary = dsr.workSummary, initialRecommendations = …, initialIecChoice = …, initialSerial = …)` — no calibration args; `var calibrationPerformed by rememberSaveable { mutableStateOf(false) }`.
- Fix: add `initialCalibrationWithinOem: Boolean?` (prefill `calibrationPerformed = it != null`, `calibChoice = if (it == true) 1 else 0`); extend the `Dsr` DTO with `calibration_lab_ref` (dsr_for_job returns the row) and prefill it, or show a warning that the lab ref must be re-entered.
- Test: Robolectric compose test rendering `DsrForm(initialCalibrationWithinOem = true, …)` with a valid summary and tapping submit → assert `onSubmit` receives `calibrationPerformed = true, calibrationWithinOem = true`.
- Owner: ME

### RH-09 [MEDIUM] Request-service phone gate blocks on a phone number cached once at bind time
- File: app/features/hospital/RequestServiceViewModel.kt:471-484 (cache), 780-785 (gate)
- What: `hospitalPhone` is fetched a single time in `bindDraftSession` and never refreshed. `onSubmit` hard-blocks with "Add your phone number on Profile → Phone number before posting a job". A hospital that follows that instruction (Profile → add phone → back; the VM survives in the back stack) is still blocked; likewise a transient profile-fetch failure at bind leaves `hospitalPhone == null` and blocks a hospital that already has a phone — with a misleading message.
- Evidence: `hospitalPhone = profile?.phone?.takeIf { it.isNotBlank() }` (only in the bind launch) … `if (hospitalPhone.isNullOrBlank()) { … return }`.
- Fix: when `hospitalPhone` is null at submit, re-fetch `profileRepository.fetchById(uid)` inside the submit coroutine before gating (and distinguish fetch failure from "no phone").
- Test: VM test — profile fetch returns `phone = null` at bind, then `phone = "+91…"`; `onSubmit(0)` → assert `jobRepository.create` called and no error message.
- Owner: ME

### RH-10 [MEDIUM] Profitability floor save failure is invisible
- File: app/features/mybids/JobProfitabilityScreen.kt:392-396, 417-423
- What: `saveFloor.onFailure` writes `error` into state while `data` stays non-null, but the screen renders `error` only in the `state.error != null && state.data == null` branch. The user taps Save, the button briefly says "Saving…", then nothing — no message, floor unchanged.
- Evidence: `_state.update { it.copy(savingFloor = false, error = e.toUserMessage(...)) }` vs `state.error != null && state.data == null -> EmptyStateView(...)`.
- Fix: render `state.error` inline under `FloorEditor` when `data != null` (or route it to the snackbar), and clear it on the next successful save.
- Test: VM test with `updateFloor` failing → `error` set; Robolectric test asserting the error text is displayed while `data != null`.
- Owner: ME

### RH-11 [MEDIUM] Engineer directory search has no in-flight cancellation — out-of-order results overwrite newer ones
- File: app/features/repair/directory/EngineerDirectoryScreen.kt:221-252 (also 160-172, 182-191, 215)
- What: `refresh()` launches a new RPC each time (debounced query, sort toggle, 4★ toggle, GPS-arrival refresh) without cancelling or sequencing the previous request. The last response to arrive wins, so a slow earlier query ("ab") can replace the rows for the current one ("abc"/sort=Nearest), with `loading` already false. `RepairJobsViewModel` solves this with `pageJob?.cancel()`; this VM does not.
- Evidence: `viewModelScope.launch { … repo.search(...).onSuccess { rows -> _state.update { it.copy(loading = false, rows = rows) } } }` with no job handle or request id.
- Fix: `private var searchJob: Job?`; `searchJob?.cancel(); searchJob = viewModelScope.launch { … }` (the repo's `runCatching` + `toUserMessage()` rethrow already make the cancelled path a no-op), or capture a monotonically increasing request id and drop stale responses.
- Test: fake repo with two `CompletableDeferred` results; call `refresh()` twice; complete #1 after #2 → assert `state.rows` equals #2's rows.
- Owner: ME

### RH-12 [LOW] `DsrViewModel.load(jobId)` is called from composition
- File: app/features/repair/DsrScreen.kt:178, 93-102
- What: `viewModel.load(jobId)` runs inside `DsrScreen`'s composable body — a side effect (mutates `jobId`, launches `refresh()`) during composition, which Compose may discard/re-run. The once-per-id guard hides most symptoms but the pattern is exactly the class the r1450-era fixes removed elsewhere.
- Evidence: `fun DsrScreen(...) { viewModel.load(jobId); val state by … }`.
- Fix: read the id from `SavedStateHandle` in the VM `init` (the route already carries it), or wrap in `LaunchedEffect(jobId) { viewModel.load(jobId) }`.
- Test: with the SavedStateHandle approach, VM unit test asserts `repo.fetch(jobId)` is invoked exactly once on construction.
- Owner: ME

### RH-13 [LOW] "now ago" / "Posted now ago" for items under a minute old
- File: app/features/repair/components/EngineerJobCard.kt:512; app/features/hospital/HospitalActiveJobsScreen.kt:479, 520-524; core/util/RelativeTime.kt:11
- What: `relativeLabel()` returns the standalone "now" for `< 1 min`; these call sites append " ago", producing "now ago" (engineer feed, Active work, hospital job cards). `MyBidsScreen` already special-cases this (r1457) — the fix never reached the sibling surfaces.
- Evidence: `job.createdAtInstant?.let { "${relativeLabel(it)} ago" } ?: "Just now"`; `postedRelative?.let { "Posted $it ago" }`.
- Fix: add `relativeAgoLabel(instant)` in core/util that returns "Just now" for the "now" case; use it in all three places.
- Test: pin `hospitalBookingLeftLabel(schedule = "", postedRelative = "now")` → "Posted just now" (currently "Posted now ago").
- Owner: ME

### RH-14 [LOW] Escrow status literal `cancelled` is not modelled — hospital-cancelled jobs show "Escrow cancelled" with empty copy
- File: app/features/repair/RepairJobDetailScreen.kt:3215, 1018-1028; core/data/escrow/RepairJobEscrowRepository.kt:44-48; supabase/migrations/20260520100000_v21_per_job_escrow_schema.sql:41-44; supabase/migrations/20260522100000_v21_escrow_on_job_cancel.sql:48-50
- What: The server CHECK allows `'cancelled'` and `v21_escrow_on_job_cancel` sets it for every pending escrow when the hospital cancels an Assigned job — a routine path, not a "future status". `EscrowRow` has no `isCancelled`, so `escrowStatusCardCopy` falls to `EscrowStatusCopy(label = "Escrow ${escrow.status}", subtitle = "")` and the accent falls to the neutral `else`.
- Evidence: `else -> EscrowStatusCopy(label = "Escrow ${escrow.status}", subtitle = "")`.
- Fix: add `val isCancelled get() = status == "cancelled"` and a branch: label "Escrow cancelled", subtitle "Nothing was charged." (hospital) / "The hospital cancelled before paying." (engineer).
- Test: pin `escrowStatusCardCopy(row(status="cancelled"), isHospital=true)` label/subtitle.
- Owner: ME

### RH-15 [LOW] "Place bid" primary CTA lacks the pre-assigned-AMC (`engineerId != null`) gate its sibling gates have
- File: app/features/repair/RepairJobDetailScreen.kt:2099-2100 (vs 3313-3340)
- What: `shouldShowUnmatchedJobBanner` / `shouldShowBidsSection` (r1482/r1483, test-locked) exclude Requested jobs that already have an engineer, but `PrimaryCta.PlaceBid` keys on `isEngineer && status == Requested` only. Any engineer who opens such a job sees a bid composer for a job that is already assigned and whose hospital never sees a bids section. (Server-side acceptance of such bids could not be verified from the snapshot's migrations; the client inconsistency stands regardless.)
- Evidence: `isEngineer && job.status == RepairJobStatus.Requested -> PrimaryCta.PlaceBid(...)`.
- Fix: `isEngineer && job.status == Requested && job.engineerId == null -> PlaceBid`; show an informational "Assigned visit" pill otherwise.
- Test: extend `AmcJobBidUiGateTest` with a hoisted `primaryCtaFor(...)` pin: Engineer + Requested + engineerId set → null.
- Owner: ME

### RH-16 [LOW] Report/invoice browser hand-off has no `ActivityNotFoundException` guard
- File: app/features/repair/RepairJobDetailScreen.kt:193-206 (contrast 1961-1985)
- What: `OpenServiceReport` / `OpenInvoice` call `context.startActivity(ACTION_VIEW)` bare; on a device/profile with no browser this throws and crashes the screen. The `Navigate to site` button in the same file wraps the identical pattern in try/catch with a toast.
- Evidence: `val intent = Intent(Intent.ACTION_VIEW, effect.url.toUri()).apply { addFlags(FLAG_ACTIVITY_NEW_TASK) }; context.startActivity(intent)`.
- Fix: shared `openUrlOrToast(context, url)` with `try { startActivity } catch (_: ActivityNotFoundException) { onShowMessage(...) }`.
- Test: Robolectric — `shadowOf(packageManager)` with no ACTION_VIEW handler; emit `OpenInvoice("https://x")` → assert no crash and message shown.
- Owner: ME

### RH-17 [LOW] Chat send queues permanently rejected messages after clearing the draft — text is lost when the outbox gives up
- File: app/features/chat/ChatViewModel.kt:197-221 (core/sync/OutboxErrorClassifier.kt:44-46)
- What: `onSend` clears `draft` optimistically and, on ANY failure, enqueues the message. A 4xx (RLS denial, `chat_conversation_closed`, body too long) is `GiveUp`-dropped by the outbox; the user sees the real error toast plus a "1 message queued — will send when back online" pill, then the message silently vanishes and the typed text is gone.
- Evidence: `.onFailure { error -> queueForRetry(self, text); _state.update { it.copy(sending = false) }; _effects.emit(ShowMessage(error.toUserMessage())) }`.
- Fix: queue only for the network class (RH-01 predicate); on permanent failure restore `draft = text` and do not enqueue.
- Test: VM test with `sendMessage` failing with `RestException(403)` → assert `outboxEnqueuer.enqueue` not called and `state.draft == text`.
- Owner: ME

### RH-18 [LOW] Sub-48 dp / semantics-less touch targets
- File: app/features/repair/RepairJobDetailScreen.kt:227-236 (36 dp), 249-263 (36 dp, `.clickable {}` with no role/label), 2845-2854 (44 dp stars); app/features/repair/RepairJobsScreen.kt:147-160 (36 dp); app/features/repair/components/RepeatBookingNudge.kt:107-120 (24 dp dismiss); app/features/repair/directory/EngineerDirectoryScreen.kt:327-339 (28 dp, no role); app/features/mybids/MyBidsScreen.kt:354-364 (Text with `.clickable`, ~20 dp tall, no role)
- What: Several primary affordances (help, report menu, notifications, nudge dismiss, directory filter, profitability/payout links) are below the 48 dp minimum and some lack `Role.Button`, unlike the r461/r458 fixes applied to the photo grid and chat send button.
- Evidence: `Modifier.size(36.dp).clip(CircleShape).background(Color.Transparent).clickable { menuOpen = true }`; `Modifier.size(24.dp).clip(CircleShape).clickable(onClick = onDismiss)`.
- Fix: wrap in `Modifier.minimumInteractiveComponentSize()` (or `size(48.dp)` with the visual kept inside) and pass `role = Role.Button` + `onClickLabel`.
- Test: Robolectric semantics test asserting each node's bounds ≥ 48×48 dp and `Role.Button` present.
- Owner: ME

### RH-19 [LOW] Hard-coded UI strings where an equivalent R.string already exists
- File: app/features/repair/RepairJobDetailScreen.kt:2434, 2607, 2785 ("Cancel"), 3048 ("Retry"); app/features/repair/directory/EngineerDirectoryScreen.kt:459 ("Try again"); app/features/hospital/HospitalMyDisputesScreen.kt:145 ("Try again")
- What: `common_cancel` and `common_retry` exist and are used elsewhere in the same screens (e.g. RequestServiceScreen.kt:239, 880; ChatScreen.kt:758), but these sites keep literals — they bypass localisation and drift from the shared copy.
- Evidence: `EsBtn(text = "Cancel", …)`, `EsBtn(text = "Retry", …)`, `ctaLabel = "Try again"`.
- Fix: `stringResource(R.string.common_cancel)` / `R.string.common_retry`.
- Test: Robolectric compose test asserting the node text equals `context.getString(R.string.common_cancel)`; optionally a lint check for hard-coded `EsBtn(text = "…")` literals.
- Owner: ME

### RH-20 [LOW] Money/number display: refund figure truncates paise; distance printed as raw Double
- File: app/features/repair/RepairJobDetailScreen.kt:434, 2945-2950; app/features/mybids/JobProfitabilityScreen.kt:487-491
- What: `escrowHeldRupees = state.escrow?.amountRupees?.toInt()` feeds `repair_cancel_escrow_refund` (an Int arg), so a ₹2,325.50 held escrow reads as "₹2325" in the refund promise. `" ($it km round trip)"` interpolates the RPC's Double verbatim (e.g. "12.345678 km round trip") while every other distance in the app is `%.1f` under `Locale.US`.
- Evidence: `escrowHeldRupees = state.escrow?.takeIf { it.isHeld }?.amountRupees?.toInt()`; `(p.distanceKm?.let { " ($it km round trip)" } ?: "")`.
- Fix: pass `formatRupees(amountRupees)` as a String arg; `"%.1f".format(Locale.US, it)` for the distance.
- Test: pin the formatted outputs in pure-function tests (`2325.5 → "₹2,325.50"`, `12.345678 → "12.3 km"`).
- Owner: ME

### RH-21 [LOW] Withdrawn bids are unreachable in My bids
- File: app/features/mybids/MyBidsScreen.kt:183, 203-209, 234-236; app/features/mybids/MyBidsViewModel.kt:45-48
- What: The tab strip offers only Pending/Accepted/Rejected, the default filter coerces `null → Pending`, and `visibleRows` filters on `activeFilter`; a `Withdrawn` bid (a status the screen's own `bidStatusPillKind` handles) is shown in no tab and its count is never surfaced. `UiState.visibleRows` (the "All" path) is dead code.
- Evidence: `listOf(Pending, Accepted, Rejected).map { … }`; `state.rows.filter { it.bid.status == activeFilter }`.
- Fix: either add a Withdrawn tab or fold Withdrawn into the Rejected tab with its own pill.
- Test: Robolectric test seeding one Withdrawn bid → assert it renders under the chosen tab; unit-pin the tab list includes Withdrawn.
- Owner: ME

### RH-22 [LOW] LocationPickerMap's initial auto-fetch captures a stale `selected` and can overwrite a pin set during the GPS window
- File: app/features/repair/components/LocationPickerMap.kt:106-142, 159-170
- What: `tryFetch` is an unremembered lambda capturing `selected` from the composition it was created in; `LaunchedEffect(Unit)` invokes the first instance. If the fix fails/times out (up to 8 s) and, meanwhile, the parent restored a pin (RequestService "Keep draft"), the stale `selected == null` check fires `onLocationPickedRef(HYDERABAD_FALLBACK)` and replaces the restored coordinates with Hyderabad city centre.
- Evidence: `if (fix == null && selected == null) { onLocationPickedRef(HYDERABAD_FALLBACK) }` inside a lambda not wrapped in `rememberUpdatedState`.
- Fix: `val selectedRef by rememberUpdatedState(selected)` and check `selectedRef` at completion time (same pattern already used for `onLocationPicked`).
- Test: Robolectric compose test with a fake location provider that resolves null after the parent flips `selected` to a non-null value → assert `onLocationPicked` is not called with the fallback.
- Owner: ME

Verified-clean areas:
- GST math: `orderSummaryBreakdown` is GST-inclusive (taxable = round(bid/1.18, 2), gst = bid − taxable, total = bid) and foots to the round449 invoice; `EngineerPayoutStatusCard` converts paise via `/ 100.0` with `%.2f`; `HospitalTierPreviewScreen` commission `Math.round(rate*100)%` matches the on-device 7% check.
- Status/bid literals: `RepairJobStatus`, `RepairBidStatus` and `CostRevisionStatus` mirror the server enums exactly (`repair_cost_revision_status` has precisely proposed/approved/rejected/expired, so `fromKey → Proposed` never misfires); `complete_repair_job` accepts assigned/en_route/in_progress so `markDone` from EnRoute is valid; `engineer_check_in_with_geo` RAISEs on geofence failure, so the client ignoring `geofencePassed` is safe; `hospital_rating`/`engineer_rating` writer semantics match the `rated` gates and `RateSheet` prefill.
- Cancellation handling: `toUserMessage()` rethrows `CancellationException`, so the `runCatching`-wrapped repositories plus `pageJob.cancel()` in `RepairJobsViewModel` and `withTimeoutOrNull` in `ConversationsViewModel.refresh` do not leave stale error/refreshing state (the timeout coroutine still completes cancelled).
- Stale-result guards: `RepairJobsViewModel.loadNext` query-capture guard; `RequestServiceViewModel` lease/`isCurrent` gating on every callback and the `key(formSession)` re-scope; `ChatViewModel`/`ConversationsViewModel` cancel prior observers on user switch; `RequestService` is popped inclusive on submit so the `formSession = null` reset is unreachable.
- Compose: all `LazyColumn`/`LazyRow` items use stable keys (job id, bid id, escrow id, message id, conversation id); `BidComposerSheet`/`RateSheet`/`FloorEditor` key their `rememberSaveable` state; `JobEscrowPaymentSheet` consumes its one-shot error; `TypingIndicatorRow` effect leaves composition when hidden.
- Double-submit gates present and correct on: acceptBid, withdrawBid, submitRating, confirmEscrowRelease, openEscrowDispute, submitEngineerResponse, propose/decideCostRevision, generateServiceReport/Invoice, DSR submit/sign, chat send/edit/report, block toggle.
- Sign-out: RLS on `repair_jobs` SELECT is participants/admin only, so the bare-`isEngineer` Rate/DSR/report CTAs on completed jobs are unreachable by non-assigned engineers; outbox handlers owner-gate queued rows by actor id.
