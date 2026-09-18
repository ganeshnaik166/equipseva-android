# Audit: money / KYC / profile / engineer surfaces — snapshot 9a0ecf89 (READ-ONLY)

Scope read in full: features/amc, features/earnings, features/payouts, core/payments, features/kyc (excluding EmailVerifySheet + KycViewModel OTP send/verify paths), features/profile (incl. forms), features/engineer, features/engineerprofile. Cross-checked against core/data repositories, core/network/DataError.kt, core/util/Money.kt, MainActivity/manifest, supabase/functions/{create-amc-payment-order,razorpay-webhook} and supabase/migrations status CHECKs.

Key cross-cutting fact used below: `Throwable.toUserMessage()` (core/network/DataError.kt:15) RE-THROWS `CancellationException`. Every repository wraps calls in `runCatching`, so a cancelled coroutine surfaces as `Result.failure(CancellationException)`; any caller that then does `_state.update { it.copy(busy=false, error = e.toUserMessage()) }` throws INSIDE the update lambda and the flag reset never lands. This is harmless in `viewModelScope` (the VM is dying anyway) but fatal in UI-scoped coroutines.

---

### F01 [HIGH] AMC top-up sheet wedges in "Processing…" forever after being dismissed mid-checkout
- File: app/src/main/kotlin/com/equipseva/app/features/amc/AmcPaymentSheet.kt:98-108,145-148,186-197,226,335-346 (+ core/network/DataError.kt:15)
- What: `runCheckout` runs in the sheet's `rememberCoroutineScope()`. Tapping the scrim/close while `createPaymentOrder` (up to 25 s) is in flight cancels that scope; the repo's `runCatching` converts the cancellation into `Result.failure(CancellationException)`, and every failure branch calls `toUserMessage()` inside `_state.update`, which rethrows before `busy=false` is applied. `AmcPaymentViewModel` is `hiltViewModel()` scoped to the AmcDetail back-stack entry, so `busy=true` persists: reopening the sheet shows a disabled "Processing…" button + spinner until the detail screen is popped.
- Evidence: `if (_state.value.busy) return false` (98) → `_state.update { it.copy(busy = false, error = orderRes.exceptionOrNull()?.toUserMessage()) }` (104-106) — the `toUserMessage()` call throws CE before `copy` runs. Same shape at 146 (`it.toUserMessage()`) and 195 (`e.toUserMessage()`). `EsBottomSheet` → `ModalBottomSheet(onDismissRequest = onClose)` (designsystem/components/EsBottomSheet.kt:38) dismisses regardless of `busy`.
- Fix: run the checkout in `viewModelScope` (return a Job/Flow the sheet observes) and wrap the body in `try { … } finally { _state.update { it.copy(busy = false) } }`; compute the message with a CE-safe helper (`if (e is CancellationException) null else e.toUserMessage()`). Also pass `busy` into `EsBottomSheet` so the scrim cannot dismiss mid-payment.
- Test: Robolectric/JUnit with a fake `AmcRepository.createPaymentOrder` that suspends until cancelled; launch `runCheckout` from a child scope, cancel it, `advanceUntilIdle()`, assert `state.value.busy == false`.
- Owner: ME

### F02 [HIGH] Razorpay checkout can open with no listener; a captured payment is then dropped client-side and may have no recovery marker
- File: app/src/main/kotlin/com/equipseva/app/features/amc/AmcPaymentSheet.kt:126,133-148; core/payments/RazorpayCheckoutLauncher.kt:113-120; features/amc/CreateAmcWizardScreen.kt:521,530-546
- What: `runCatching { pendingPaymentsStore.add(order.paymentOrderId) }` swallows the CancellationException from a DataStore write interrupted by scope cancellation (sheet dismissed / wizard popped after `createPaymentOrder` returned). Execution continues into `launcher.startPayment`, which calls `checkout.open(activity, options)` BEFORE `deferred.await()` throws; the `finally` clears `PaymentBridge`. The Razorpay activity is now on screen with `pending == null`; if the hospital pays, `completeSuccess` returns early, no verify call is made, no toast, and — if the DataStore edit did not commit — no marker exists for `PendingAmcPaymentsReconciler`. Credit then depends entirely on the razorpay-webhook path.
- Evidence: `runCatching { pendingPaymentsStore.add(order.paymentOrderId) }` (126) → `launcher.startPayment(...)` (134) → `checkout.open(activity, options); deferred.await()` (116-117) → `PaymentBridge.completeSuccess`: `val pending = pending ?: return` (149).
- Fix: replace the `runCatching` around marker writes with `try/catch (e: CancellationException) { throw e }`; call `coroutineContext.ensureActive()` immediately before `checkout.open`; move the whole flow to `viewModelScope` (F01) so a sheet dismissal cannot cancel it.
- Test: unit test with a fake store whose `add` throws `CancellationException` (or suspends until the test cancels the job) and a fake launcher; assert `startPayment` is never invoked after cancellation.
- Owner: ME

### F03 [HIGH] Verify-after-Razorpay-success has no retry and no client recovery; wizard path hides it with misleading copy and no CrashReporter
- File: app/src/main/kotlin/com/equipseva/app/features/amc/AmcPaymentSheet.kt:170-199; features/amc/CreateAmcWizardScreen.kt:556-575,466-482; core/payments/PendingAmcPaymentsReconciler.kt:34-64; core/payments/PendingAmcPaymentsStore.kt:42-48
- What: After `RazorpayPaymentResult.Success`, a single `verifyPayment` (20 s timeout) is attempted. On failure the marker is kept but nothing ever re-runs verify: the reconciler only stores the order id and only CLEARS markers by server status; the `razorpay_payment_id`/`signature` are discarded. The server verify is idempotent (`VerifyAmcPaymentResponse.idempotent`), so a bounded retry is safe and cheap. In the wizard the failure is indistinguishable from a cancel: the hospital sees "Contract pending payment… cancelled in 24 hours" after being charged, and no `crashReporter.report` fires (the sheet path does report).
- Evidence: sheet `verifyRes.fold(onFailure = { … false })` (186-197); wizard `if (verifyRes.isSuccess) {…} else { false }` (563-574) → `onShowMessage("Contract pending payment. Complete it from the AMC detail screen or it will be cancelled in 24 hours.")` (477-480); reconciler `if (shouldClearAmcPaymentMarker(result.getOrNull())) store.remove(id)` (54-56) — no verify call. Fallback exists only in supabase/functions/razorpay-webhook/index.ts:144-160 (`record_razorpay_payment_captured`), i.e. only if the Razorpay dashboard webhook is configured.
- Fix: (1) retry `verifyPayment` up to 2× with backoff on non-4xx failures before giving up; (2) persist `{paymentOrderId, razorpayOrderId, razorpayPaymentId, signature}` in the pending store and have the reconciler call `verifyPayment` for entries whose server status is still `pending`; (3) wizard: distinguish verify-failure copy ("Payment received, confirming…") and call `crashReporter.report`.
- Test: fake repo whose `verifyPayment` fails once then succeeds → assert marker removed and `true` returned; reconciler test with a stored payload + `fetchAmcPaymentOrderStatus == "pending"` → assert `verifyPayment` invoked.
- Owner: ME

### F04 [HIGH] KYC `onCleared` orphan-cleanup deletes documents that an in-flight `save()` just persisted
- File: app/src/main/kotlin/com/equipseva/app/features/kyc/KycViewModel.kt:93-123,128-134,1008-1038
- What: `persistedDocPaths` is refreshed only in `hydrate()` (load + after upsert success). If the engineer leaves the screen (system back / top-bar back, neither gated on `saving`) while `engineerRepository.upsert` is in flight, the VM is cleared, `viewModelScope` is cancelled before `hydrate(engineer)` runs, and `onCleared` computes `live - persistedDocPaths` = all newly uploaded paths and deletes them from `kyc-docs` via `GlobalScope`. The server-side upsert (already sent) succeeds, so the engineer row references deleted files; the review queue shows a submission with missing docs.
- Evidence: `val orphans = live - persistedDocPaths; … storageRepository.delete(bucket = KYC_DOCS, path = path)` (109-118); `persistedDocPaths` only assigned in `snapshotPersistedDocs` (128-134) called from `hydrate` (544); `save()` → `.fold(onSuccess = { engineer -> hydrate(engineer) … })` (1035-1037). Top bar `onBack` in KycScreen.kt:190-194 is not disabled while `state.saving`.
- Fix: set `persistedDocPaths = live` (or a `submitInFlight` flag that suppresses cleanup) immediately BEFORE calling `upsert`, and block back navigation while `saving`; alternatively move orphan cleanup server-side.
- Test: JUnit with a fake `EngineerRepository.upsert` that suspends until signalled; call `save()`, then simulate `onCleared()` (invoke via reflection/`ViewModelStore.clear()`), assert `storageRepository.delete` is never called for the uploaded paths.
- Owner: ME

### F05 [MEDIUM] KYC document picker reads the whole file on the main thread with no pre-read size cap
- File: app/src/main/kotlin/com/equipseva/app/features/kyc/KycScreen.kt:143-177,1133-1167 (validator: core/storage/UploadValidator.kt:26,58)
- What: `readAndUpload` runs inside the `rememberLauncherForActivityResult` callback (main thread): `ContentResolver.query` + `openInputStream(uri).readBytes()`. `OpenDocument` can return cloud-backed URIs (Drive downloads on open) and arbitrarily large PDFs; the 15 MB `UploadValidator` limit is only applied AFTER the full byte array exists. Result: ANR on slow providers, OOM on oversize files. A `null` MIME from the provider also disables the offline queue (`tryQueuePhotoUpload` returns null on null contentType, KycViewModel.kt:951).
- Evidence: `val bytes = try { resolver.openInputStream(uri)?.use { it.readBytes() } }` (1142-1147) called synchronously from `uri?.let { readAndUpload(context, it, …) }` (146-152).
- Fix: move the read into the ViewModel (`viewModelScope.launch(Dispatchers.IO)`), check `OpenableColumns.SIZE` / stream length against 15 MB before reading, and default MIME from the file extension when `getType` is null.
- Test: Robolectric test with a `ContentProvider` shadow returning a 20 MB stream → assert upload rejected without allocating; and a main-thread assertion (`Looper.getMainLooper()` check) inside a fake `uploadAadhaarDoc`.
- Owner: ME

### F06 [MEDIUM] Engineer Jobs hub shows "Become a verified engineer / Submit KYC" to a VERIFIED engineer on any fetch failure
- File: app/src/main/kotlin/com/equipseva/app/features/engineer/EngineerJobsHubScreen.kt:101-107,187-205
- What: `refresh()` maps every repository failure (network blip, PGRST301 refresh race, RLS hiccup) to `Status.NotEngineer`, which renders the onboarding hero and hides all hub tiles (Available jobs, Active work, Earnings…). `RefreshOnReturn` re-triggers it on every resume, so a flaky connection repeatedly downgrades a verified engineer's UI and invites a re-submit of KYC.
- Evidence: `.onFailure { _state.update { it.copy(status = Status.NotEngineer) } }` (106).
- Fix: keep the previous status on failure (`if (it.status == Status.Loading) Status.Error else it.status`) and add an `Error` state with retry.
- Test: VM test — first fetch returns Verified, second returns failure → assert status stays Verified.
- Owner: ME

### F07 [MEDIUM] AMC wizard: Back is live during submit; navigation + toast fire after the wizard is popped, and the pending-contract marker write is swallowed
- File: app/src/main/kotlin/com/equipseva/app/features/amc/CreateAmcWizardScreen.kt:452-483,502-509,620-624,661-669
- What: Neither the top-bar back nor the "Back" footer button is disabled while `submitting`. If the user backs out after `createContract` succeeded (during `pendingContractsStore.add` or `createPaymentOrder`), the VM is cleared: `runCatching { pendingContractsStore.add(newId) }` swallows the CancellationException (marker may never be written → Home banner never shows the stranded `pending_payment` contract), `runCheckout` returns false without `toUserMessage`, and the non-suspending tail still runs: `onShowMessage("Contract pending payment…")` + `onSuccess(newId)` navigates to the new contract from whatever screen the user is now on. Razorpay `Failed` reasons are also never surfaced (same generic copy).
- Evidence: `if (orderRes.isFailure) return false` (509) → `_state.update { it.copy(submitting = false) }; … onShowMessage(...); onSuccess(newId)` (472-482); `EsBtn(text = "Back", onClick = { … onBack() … })` has no `disabled` (661-669).
- Fix: disable both back affordances while `submitting`; `ensureActive()` before `onShowMessage`/`onSuccess`; write the contract marker with `try/catch(CancellationException) { throw }`.
- Test: VM test with `createContract` succeeding and `createPaymentOrder` suspending; cancel `viewModelScope`; assert `onSuccess` never invoked and `pendingContractsStore.add` completed or rethrew.
- Owner: ME

### F08 [MEDIUM] "Contract paused" banner fires when the pool-balance fetch fails or on cancelled/expired contracts
- File: app/src/main/kotlin/com/equipseva/app/features/amc/AmcDetailScreen.kt:404,432 (PausedBanner 636-663)
- What: `balance = state.poolBalance ?: 0.0` collapses "fetch failed" into zero, and `pausedByServer || balance <= 0.0` then renders the red "paused" banner while the status pill says Active (transient `getPoolBalance` failure is best-effort, `refresh()` 188-189). The same branch also shows "paused" on `cancelled`/`expired` contracts with an empty pool.
- Evidence: `val balance = state.poolBalance ?: 0.0` (404); `pausedByServer || balance <= 0.0 -> PausedBanner()` (432).
- Fix: gate on `state.poolBalance != null && balance <= 0.0 && status in {active}`; show nothing (or a neutral "balance unavailable") when the fetch failed.
- Test: Compose/Robolectric test rendering the screen with `poolBalance = null, status = "active"` → assert paused banner absent; with `status = "cancelled", poolBalance = 0.0` → absent.
- Owner: ME

### F09 [MEDIUM] Action failures written to an `error` field the loaded screen never renders (silent failures)
- File: app/src/main/kotlin/com/equipseva/app/features/amc/AmcDetailScreen.kt:301-307 (+372-378); features/profile/EngineerReferralScreen.kt:140-157 (+178); features/profile/KycRenewalScreen.kt:87-103 (+122)
- What: `removeFallback`, `confirm(referralId)`, `startRenewal`, `markItemRefreshed` set `state.error` on failure, but each screen only renders `error` in its empty/not-loaded branch. With content loaded the user gets no feedback; the row simply does not change. AmcDetail's own r1449 comment documents this dead end for other actions but `removeFallback` still uses it. `removeFallback` also has no busy guard (double tap → second RPC fails silently).
- Evidence: `.onFailure { e -> _state.update { it.copy(error = e.toUserMessage()) } }` (AmcDetailScreen 305); `when { … state.hospital == null && state.engineerView == null -> Text(state.error ?: …) }` (372-378); Referral: `state.error != null && state.referrals.isEmpty() && state.myUserId == null -> EmptyStateView` (178); Renewal: `state.error != null && state.renewal == null -> EmptyStateView` (122).
- Fix: route action failures through the existing one-shot message channel (`_autoPayMessage.tryEmit` in AmcDetail; add a `SharedFlow<String>` effect in Referral/Renewal) and render inline like AddressBookScreen.kt:180-188 does.
- Test: VM tests asserting the effect flow emits on repo failure; UI test asserting a snackbar/inline error appears while rows are present.
- Owner: ME

### F10 [MEDIUM] Grievance / portal composers stay open after success with Submit re-enabled; VMs lack in-flight guards → duplicate filings
- File: app/src/main/kotlin/com/equipseva/app/features/profile/DpdpGrievanceScreen.kt:99-115,178-191,227-237; features/amc/HospitalPortalScreen.kt:139-165,226-232,262-269; features/profile/EngineerReferralScreen.kt:124-157; features/profile/KycRenewalScreen.kt:87-103
- What: `GrievanceComposer` receives `submitted` but never uses it; on success the composer stays open with the description intact and the Submit button re-enabled (`disabled = submitting || …`), so the only visible change is the history list below — a second tap files a duplicate DPDP grievance (statutory-SLA row). Hospital portal composers show a note but likewise keep fields + button live. None of `submit`, `submitRequest`, `submitDispute`, `registerReferral`, `confirm`, `startRenewal`, `markItemRefreshed` check an in-flight flag before launching, so a double tap inside one frame fires two RPCs.
- Evidence: `GrievanceComposer(… submitted: Boolean …)` parameter unused in body (227-308); `fun submit(...) { _state.update { it.copy(submitting = true …) }; viewModelScope.launch { … } }` with no `if (submitting) return` (99-113).
- Fix: on `submitted` close the composer and clear draft state; add `if (_state.value.submitting) return` guards (pattern already used by `AmcDetailViewModel.cancel()` and `EngineerPayoutMethodViewModel.save()`).
- Test: VM test calling `submit()` twice synchronously with a suspended fake repo → assert single repo invocation; UI test asserting composer hidden after `submitted = true`.
- Owner: ME

### F11 [MEDIUM] AMC visit payout rows are indistinguishable — every row is titled "AMC visit" and the completion date is never shown
- File: app/src/main/kotlin/com/equipseva/app/features/earnings/EarningsScreen.kt:537-591 (title 558-563); core/data/amc/AmcRepository.kt:220-227
- What: `AmcEarningsList` renders `stringResource(R.string.engineer_amc_visits_job_number_fallback)` ("AMC visit", strings.xml:500) as the title of EVERY row and ignores `visitCompletedAt`; `EngineerAmcEarning` carries no hospital/job number. The engineer's money ledger for AMC therefore cannot be reconciled against visits ("Visit cost ₹X · Platform ₹Y" repeated N times).
- Evidence: `Text(text = stringResource(R.string.engineer_amc_visits_job_number_fallback) …)` (559) inside `rows.forEach`.
- Fix: render `prettyDate(row.visitCompletedAt)` as the primary line and extend `list_my_amc_earnings` (or join client-side with `listMyAmcVisits`) to include hospital name / visit number.
- Test: Compose test with two rows → assert two distinct titles containing their dates.
- Owner: ME

### F12 [LOW] Earnings ViewModel does not reset per-user slices when the signed-in user changes
- File: app/src/main/kotlin/com/equipseva/app/features/earnings/EarningsViewModel.kt:76-83,157-184
- What: `distinctUntilChangedBy { it.userId }` re-runs `load()` for a new user, but `loadEscrowSummary/loadSelfRank/loadAmcEarnings/loadPayouts` are "quiet on failure", so a failed fetch leaves the PREVIOUS user's escrow totals, rank, AMC payouts and transfer rows on screen.
- Evidence: `escrowRepository.fetchEngineerSummary().onSuccess { … } // Quiet on failure — card hides.` (158-161) with no reset in `load()` (87-115).
- Fix: `_state.value = UiState()` when `userId` changes before `load(initial = true)`.
- Test: VM test emitting SignedIn(A) → success, SignedIn(B) → failing fakes; assert `escrowSummary == null`.
- Owner: ME

### F13 [LOW] Supervision screen wipes its own confirmation toast and picker on reload
- File: app/src/main/kotlin/com/equipseva/app/features/engineer/EngineerSupervisionScreen.kt:92-110,112-129
- What: `reload()` replaces state with a fresh `UiState(status = Loaded, rows = list)`, dropping `toast` ("Accepted"/"Declined"/"Signed off"/"Request sent") set microseconds earlier and resetting `pickerOpen`. The sibling `EngineerDemandSignalsViewModel.reload()` (EngineerDemandSignalsScreen.kt:90-93) explicitly fixed this with `it.copy(...)`.
- Evidence: `_state.update { UiState(status = Status.Loaded, rows = list) }` (99).
- Fix: `_state.update { it.copy(status = Status.Loaded, rows = list, error = null) }`.
- Test: VM test — `accept()` with fake success → after `advanceUntilIdle()` assert `toast == "Accepted"`.
- Owner: ME

### F14 [LOW] "Visits this year" shows 0 when exactly a full year of visits is complete
- File: app/src/main/kotlin/com/equipseva/app/features/amc/AmcDetailScreen.kt:811,1136
- What: `visitsDone % visitsPerYr` yields 0 for `visitsDone == visitsPerYr` (or any multiple), so a contract that just completed its 12th of 12 visits reads "0 / 12 this year" on both Overview and Visits tabs.
- Evidence: `val visitsDoneThisYear = if (visitsPerYr > 0) visitsDone % visitsPerYr else visitsDone` (811, 1136).
- Fix: derive the contract year from `startDate` and subtract prior years' quota, or `if (visitsDone > 0 && visitsDone % visitsPerYr == 0) visitsPerYr else visitsDone % visitsPerYr`.
- Test: pure-function unit test: (12,12)→12, (13,12)→1, (0,12)→0.
- Owner: ME

### F15 [LOW] Wizard money/SLA input drift: renewal prefill truncates paise; decimal SLA hours pass validation but are silently replaced
- File: app/src/main/kotlin/com/equipseva/app/features/amc/CreateAmcWizardScreen.kt:268,421-422,1176-1183
- What: Renew-prefill uses `prior.monthlyFeeRupees.toLong().toString()` (₹2,999.50 → "2999"), lowering the renewed fee without the hospital noticing. `canProceedSlaStep` accepts any positive Double ("2.5"), but `submitAndPay` does `toIntOrNull()?.coerceAtLeast(1) ?: 4/24`, so "2.5" becomes the default 4 h / 24 h.
- Evidence: `val fee = prior.monthlyFeeRupees.toLong().toString()` (268); `val emergency = s.responseTimeEmergencyHours.toIntOrNull()?.coerceAtLeast(1) ?: 4` (421).
- Fix: prefill with `formatRate`-style exact string; validate SLA hours as Int in `canProceedSlaStep` (or round explicitly and show it).
- Test: unit tests on `canProceedSlaStep("2.5", "24") == false`; prefill test asserting "2999.5".
- Owner: ME

### F16 [LOW] Whole-rupee rounding on amounts that are paise-exact (Pay button vs Razorpay sheet; transfers ledger)
- File: app/src/main/kotlin/com/equipseva/app/features/amc/AmcPaymentSheet.kt:232,295,320,329; features/earnings/EarningsScreen.kt:723,742; core/util/Money.kt:38-43
- What: `formatRupees` rounds to whole rupees (ties-to-even). The sheet computes `total = monthlyFeeRupees * months` client-side and shows "Pay ₹3,000" while the server charges `round(fee*months*100)/100` (create-amc-payment-order/index.ts:116) — e.g. ₹2,999.99 in the Razorpay UI. `PayoutTransferRow` converts exact `amountPaise` to Double and rounds it, so the "ground-truth ledger" of bank transfers shows ₹1,235 for a ₹1,234.56 UTR.
- Evidence: `text = if (state.busy) "Processing…" else "Pay ${formatRupees(total)}"` (329); `val amountRupees = p.amountPaise / 100.0 … formatRupees(amountRupees)` (723,742).
- Fix: use `formatRupeesPaise` for the Pay button/total and the transfers ledger (or display `order.amountPaise` returned by the server after order creation).
- Test: unit test `formatRupeesPaise(1234.56) == "₹1,234.56"` wired into a `payoutRowAmountText(amountPaise)` helper.
- Owner: ME

### F17 [LOW] Touch targets < 48dp and fixed-height buttons that clip large text
- File: app/src/main/kotlin/com/equipseva/app/features/amc/AmcDetailScreen.kt:1365-1376; features/amc/CreateAmcWizardScreen.kt:917-927; features/profile/ProfileScreen.kt:1038-1051; features/engineerprofile/EngineerProfileScreen.kt:341-357; features/payouts/EngineerPayoutMethodScreen.kt:229-235; features/kyc/KycScreen.kt:1103-1117
- What: Plain `Box.clickable` icons with 8 dp / 6 dp padding (≈40 dp / 36 dp) for "Remove engineer"; ProfileHero "Edit" chip ≈28 dp tall; `AvailabilityButton` ≈40 dp; `ModeToggle` fixed `height(44.dp)`; KYC stepper buttons fixed `.height(48.dp)` so "Re-submit for review" wraps and clips at font scale ≥1.3.
- Evidence: `.clickable(onClickLabel = removeLabel) { onRemove() }.padding(8.dp)` (AmcDetail 1368-1369); `.clickable { onRemoveFallback(opt.engineerId) }.padding(6.dp)` (Wizard 919-920); `Modifier.fillMaxWidth().height(44.dp)` (Payout 232); `.height(Spacing.MinTouchTarget)` (Kyc 1108,1116).
- Fix: `Modifier.minimumInteractiveComponentSize()` / `sizeIn(minWidth = 48.dp, minHeight = 48.dp)` on the tap targets; `heightIn(min = 48.dp)` instead of `height`.
- Test: Robolectric semantics test asserting bounds ≥ 48×48 dp for the remove/edit nodes; screenshot test at fontScale 1.5 for the KYC bottom bar.
- Owner: ME

### F18 [LOW] Hard-coded user-facing strings on the money and KYC paths (not localizable, drift from strings.xml)
- File: app/src/main/kotlin/com/equipseva/app/features/amc/AmcPaymentSheet.kt:155,165,249,268,329,332,343; features/amc/CreateAmcWizardScreen.kt:475-480,621,662,674-676,681; features/amc/AmcDetailScreen.kt:65,73,148,406,429,512,542,592-594,641-644,772-776,838-841; core/payments/RazorpayCheckoutLauncher.kt:190-203; features/earnings/EarningsScreen.kt:86,139-140,204-206,229-230,247,267,320-321,387-393,778-790,808-817,867-873; features/payouts/EngineerPayoutMethodScreen.kt:81,159,211-213,237-244,299-311,338-373; features/kyc/KycViewModel.kt:216-239,799-801,824-931,974; features/kyc/KycScreen.kt:191,386,395,408,472,551,560,604,616,622,644,662,671,679,1032-1035,1184-1220,1264-1266; features/profile/ProfileScreen.kt:180,740-902,1382,1445,1448; features/engineer/EngineerJobsHubScreen.kt:175,218-290,425-444
- What: Literal English copy (button labels, error/validation messages, tab labels, payment status text, onboarding hero) bypasses resources while sibling strings in the same files use `stringResource`; a locale switch leaves the payment and KYC flows half-translated.
- Evidence: e.g. `error = "Payment cancelled"` (AmcPaymentSheet 155); `"Contract pending payment. Complete it from the AMC detail screen or it will be cancelled in 24 hours."` (Wizard 478-479); `"Aadhaar must be 12 digits."` (KycViewModel 232).
- Fix: move to strings.xml; for VM-side copy expose resource ids / sealed error types and resolve in the composable.
- Test: lint rule (`HardcodedText` is Compose-blind) — add a unit test that scans these files for `Text("` / `text = "` literals, or a Roborazzi screenshot in a pseudo-locale.
- Owner: ME

### F19 [LOW] Legacy `BankDetailsScreen` stores the full bank account number in plaintext `user_settings` JSON and is still a registered destination
- File: app/src/main/kotlin/com/equipseva/app/features/profile/forms/ProfileForms.kt:309-332 (+ navigation/MainNavGraph.kt:1144-1149, navigation/Routes.kt:151)
- What: The generic settings form writes `account_number` / `ifsc` verbatim to the `bank_details` JSONB key and re-renders them unmasked; the real payout destination lives in `engineer_payout_methods` via `EngineerPayoutMethodScreen`. Nothing navigates to `profile/bank_details` today, but the composable is still registered, so any future/deep-link route string reaches a second, unencrypted source of truth for bank data.
- Evidence: `FieldSpec("account_number", "Account number", FieldKind.NUMBER)` (325); `composable(Routes.PROFILE_BANK_DETAILS) { BankDetailsScreen(...) }` (MainNavGraph 1144).
- Fix: delete `BankDetailsScreen` + `Routes.PROFILE_BANK_DETAILS` registration (route removal touches the nav graph — coordinate).
- Test: compile-time removal; nav test asserting `navigate("profile/bank_details")` throws IllegalArgumentException.
- Owner: ME (screen) / OWNED-BY-COORDINATOR (nav graph + deep-link allow-list)

### F20 [LOW] Concurrent `refresh()` calls on AMC detail are not cancelled — stale pool balance can overwrite the post-payment one
- File: app/src/main/kotlin/com/equipseva/app/features/amc/AmcDetailScreen.kt:139-208,277,570-573
- What: `RefreshOnReturn` fires `refresh()` on the resume that follows the Razorpay activity while `verifyPayment` is still running; `onCompleted` fires a second `refresh()`. Each `viewModelScope.launch` performs 6 sequential fetches; whichever finishes last wins, so the pre-credit `getPoolBalance` value can land after the post-credit one.
- Evidence: `fun refresh() { … viewModelScope.launch { … repo.getPoolBalance(contractId).onSuccess { v -> _state.update { it.copy(poolBalance = v) } } … } }` (139-208) with no Job tracking.
- Fix: keep `private var refreshJob: Job?` and `cancel()` it at the top of `refresh()`.
- Test: VM test with two overlapping refreshes where the first fake returns later with an older balance → assert final balance is the second one.
- Owner: ME

### F21 [LOW] Fallback-engineer picker search has no debounce/cancellation → stale results race
- File: app/src/main/kotlin/com/equipseva/app/features/amc/CreateAmcWizardScreen.kt:356-389
- What: Every keystroke launches `engineerRepo.search`; a slower earlier query can complete after a later one and overwrite `pickerResults`/`pickerLoading=false` with results for a stale prefix.
- Evidence: `fun setPickerQuery(q: String) { _state.update {…pickerLoading = true}; viewModelScope.launch { engineerRepo.search(query = q…) … } }` (356-389).
- Fix: track a `searchJob`, cancel on each call, and/or ignore results whose query != `state.pickerQuery`.
- Test: VM test with two queries and reversed completion order → assert results match the latest query.
- Owner: ME

### F22 [LOW] Address form: "set as default" result ignored; phone accepts any non-blank string
- File: app/src/main/kotlin/com/equipseva/app/features/profile/forms/AddressFormScreen.kt:216-223,314-323,419-422,524-534
- What: `repo.setDefault(saved.id)` return value is discarded — a failed default flip still reports success and pops the screen. The address phone is only checked for `isNotBlank()` (a single digit saves), unlike every other phone field which validates a 10-digit Indian mobile.
- Evidence: `if (f.isDefault && saved.id != null) { repo.setDefault(saved.id) }` (218-220); `f.phone.isNotBlank()` (419); `validateAddressForm` has no phone shape check (524-534).
- Fix: fold `setDefault` failure into `error`; reuse `Validators::indiaMobileError` (as HospitalAddressesScreen does).
- Test: unit test `validateAddressForm(phone = "1") != null`; VM test with failing `setDefault` → `saved == false`, `error != null`.
- Owner: ME

### F23 [LOW] KYC Personal step blocks on a transient profile-fetch failure with misleading copy
- File: app/src/main/kotlin/com/equipseva/app/features/kyc/KycViewModel.kt:381-394,214-219
- What: `profileRepository.fetchById(uid).getOrNull()` swallows the failure; `fullName/email` become null and `stepError()` tells the engineer "Add your name from Profile settings before continuing." although the profile exists. No retry affordance is offered for that half of the load.
- Evidence: `val profile = profileRepository.fetchById(uid).getOrNull()` (381); `fullName.isNullOrBlank() -> "Add your name from Profile settings before continuing."` (216).
- Fix: treat profile-fetch failure like engineer-fetch failure (`errorMessage` + Retry).
- Test: VM test with failing profile fake → assert `errorMessage != null` rather than a stepError.
- Owner: ME

### F24 [LOW] Hospital portal: disputes fetch failure is silently rendered as "no disputes"
- File: app/src/main/kotlin/com/equipseva/app/features/amc/HospitalPortalScreen.kt:118-137
- What: `refresh()` only surfaces `requests.isFailure`; a failed `fetchMyDisputes` yields `getOrDefault(emptyList())`, so the Disputes tab shows the empty-state copy instead of an error/retry.
- Evidence: `disputes = disputes.getOrDefault(emptyList())` (133).
- Fix: surface either failure (or per-tab error state).
- Test: VM test with `fetchMyDisputes` failing → assert `error != null`.
- Owner: ME

---

Verified-clean areas:
- Server status/enum literals used by these screens all match migrations: `amc_payment_orders.status` (pending/paid/failed/refunded), `repair_job_escrow.status` (pending/held/released/refunded/in_dispute), `amc_contracts.status` incl. `pending_payment`/`renewal_failed`, `amc_pool_ledger.ledger_kind` (credit/debit/refund), `amc_subscriptions.status` (8 values), `equipment_pm_schedule.status`, `kyc_renewals.status` (`my_kyc_renewal` filters to pending/in_progress so the UI's two-way branch is correct), `dpdp_grievances.status`, hospital-portal request/dispute statuses, `engineer_payouts.status`.
- `PendingAmcPaymentsReconciler` / `PendingEscrowPaymentsReconciler`: CancellationException handled explicitly; row-missing vs fetch-failure distinguished; forward-compat "keep unknown status" pinned.
- `RazorpayCheckoutLauncher` / `PaymentBridge` wiring: MainActivity implements `PaymentResultWithDataListener`; manifest `configChanges` covers orientation/locale/uiMode so the Activity (and the bridge's deferred) survives rotation during checkout; amount sent as server-computed paise `Long`.
- Server-side AMC amount authority: `create-amc-payment-order` computes `amount_paise` from `monthly_fee_rupees` and `months` (1..36) and reuses an open pending order; the client never sends an amount.
- KYC PII: no `Log.*`/`println` in scope; Aadhaar masked to last-4 in `VerifiedSummaryCard`; `SecureScreen()` on KYC/Earnings/Profile; stored object names sanitized by `timestampedName` (`[^A-Za-z0-9._-]` → `_`, path separators stripped); `UploadValidator` enforces MIME allow-list (images + PDF) and 15 MB for `kyc-docs`; `ExifScrubber` runs before upload.
- Aadhaar Verhoeff + PAN regex validators, ASCII-only digit sanitizers (Aadhaar/PAN/OTP/experience/radius/phone/pincode/hourly rate).
- Payout method: VPA/IFSC/account-number validation, confirm-field match, account number never repopulated client-side, `saving` guard on `save()`.
- Compose `remember`/`LaunchedEffect` keys: effect collectors keyed on `viewModel`; `LaunchedEffect(state.error)` + `consumeError()` in the payment sheet; toast auto-clear keyed on `state.toast`; `rememberSaveable` used for months picker, composers, dialogs.
- Double-submit guards present on: `AmcPaymentViewModel.runCheckout` (busy), `CreateAmcWizardViewModel.submitAndPay`, `AmcDetailViewModel.cancel/setupAutoPay/cancelAutoPay`, `EngineerPayoutMethodViewModel.save`, `KycViewModel.save/upload*`, `ProfileViewModel` (role/edit/delete/export/sign-out), `AddressBookViewModel.setDefault/delete`, `ProfileFormViewModel.onSave`, `EngineerProfileViewModel.onSave`, `EngineerLocationViewModel.onSave`.
- `runCatching` swallowing CancellationException outside the checkout paths (`AmcDetailViewModel`, `MaintenanceContractsViewModel`, `ProfileViewModel`, `KycViewModel.tryQueuePhotoUpload/reverseGeocode`) is confined to `viewModelScope` and has no observable effect beyond VM teardown.
- Read-only screens (HospitalAmcTierPerks, HospitalAssetHistory, HospitalFleetHealth, HospitalPmCalendar, MaintenanceContracts, CommissionTier, ProfileCompleteness, EngineerAmcVisits, EngineerMyDisputes, EngineerActiveEscrows, EngineerEarningsProjection, EngineerGraduation, EngineerLocation): loading/error/empty branches correct, LazyColumn keys unique (fleet key is the 4-tuple), Locale.US used for numeric formatting, `daysUntilDue` sign handled before rounding.
