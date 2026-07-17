package com.equipseva.app.features.hospital

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.engineers.EngineerDirectoryRepository
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import com.equipseva.app.core.data.repair.RepairJobDraft
import com.equipseva.app.core.data.repair.RepairJobRepository
import com.equipseva.app.core.data.repair.RepairJobUrgency
import com.equipseva.app.core.data.repair.RequestServiceDraftStore
import com.equipseva.app.core.data.repair.RequestServiceFormDraft
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.storage.StorageRepository
import com.equipseva.app.core.util.sanitizeServerName
import com.equipseva.app.core.util.timestampedName
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.distinctUntilChangedBy
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.ZoneId
import javax.inject.Inject

@HiltViewModel
class RequestServiceViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
    private val jobRepository: RepairJobRepository,
    private val storageRepository: StorageRepository,
    private val savedStateHandle: SavedStateHandle,
    private val draftStore: RequestServiceDraftStore,
    private val engineerDirectoryRepository: EngineerDirectoryRepository,
    private val analytics: com.equipseva.app.core.data.analytics.AnalyticsClient,
    private val crashReporter: com.equipseva.app.core.observability.CrashReporter,
) : ViewModel() {

    // Round 453 — process-death-safe draft state. Hospital booking is a
    // 4-step wizard, often filled out over several minutes (issue field
    // can be 2k chars). Without this the user goes to another app to
    // copy-paste a serial number, the OS kills our process in the
    // background, and they return to a blank form with everything lost.
    private object SavedKeys {
        const val CATEGORY = "req.category"
        const val URGENCY = "req.urgency"
        const val BRAND = "req.brand"
        const val MODEL = "req.model"
        const val SERIAL = "req.serial"
        const val SITE_ADDRESS = "req.siteAddress"
        const val SITE_LOCATION = "req.siteLocation"
        const val PICKED_DATE = "req.pickedDate"
        const val SITE_LAT = "req.siteLat"
        const val SITE_LNG = "req.siteLng"
        const val ISSUE = "req.issue"
        const val BUDGET = "req.budget"
        const val PHOTOS = "req.photos"
        // v0.3.5 fix #9 — engineerId carried as a query arg from the
        // RepairJobDetailScreen Book-again CTA. Persisted in
        // SavedStateHandle so a process kill doesn't lose the
        // pre-fill (the reassurance header has to stay across a cold
        // restart or the user is suddenly typing in a generic form).
        const val ENGINEER_ID = "req.engineerId"
    }

    data class UiState(
        val category: RepairEquipmentCategory = RepairEquipmentCategory.ImagingRadiology,
        val urgency: RepairJobUrgency = RepairJobUrgency.Scheduled,
        val brand: String = "",
        val model: String = "",
        val serial: String = "",
        val siteAddress: String = "",
        val siteLocation: String = "",
        val pickedDateMillis: Long? = null,
        val siteLatitude: Double? = null,
        val siteLongitude: Double? = null,
        val issue: String = "",
        val budget: String = "",
        val budgetError: String? = null,
        val photos: List<String> = emptyList(),
        val uploadingPhoto: Boolean = false,
        val submitting: Boolean = false,
        val errorMessage: String? = null,
        val issueError: String? = null,
        val siteAddressError: String? = null,
        // Round 471 — sticky bar shown at top of form when a previously
        // saved draft is recovered from RequestServiceDraftStore. User
        // taps Keep (restore fields) or Discard (wipe + start fresh).
        val showDraftRecoveryBar: Boolean = false,
        // v0.3.5 fix #9 — engineer re-booking. When the hospital taps
        // "Book this engineer again" on a completed job detail, the
        // nav route carries engineerId; this VM fetches the
        // engineer_public_profile RPC to fill the reassurance header
        // (name + rating + jobs done) so the user keeps confidence
        // through the form. Null on a fresh open-from-Home booking.
        val prefilledEngineerId: String? = null,
        val prefilledEngineerName: String? = null,
        val prefilledEngineerRating: Double? = null,
        val prefilledEngineerJobCount: Int = 0,
    )

    sealed interface Effect {
        data class Submitted(val jobId: String, val jobNumber: String?) : Effect
        data class ShowMessage(val text: String) : Effect
    }

    private val _state = MutableStateFlow(restoredInitialState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private fun restoredInitialState(): UiState {
        val category = savedStateHandle.get<String>(SavedKeys.CATEGORY)
            ?.let { name -> runCatching { RepairEquipmentCategory.valueOf(name) }.getOrNull() }
            ?: RepairEquipmentCategory.ImagingRadiology
        val urgency = savedStateHandle.get<String>(SavedKeys.URGENCY)
            ?.let { name -> runCatching { RepairJobUrgency.valueOf(name) }.getOrNull() }
            ?: RepairJobUrgency.Scheduled
        return UiState(
            category = category,
            urgency = urgency,
            brand = savedStateHandle.get<String>(SavedKeys.BRAND).orEmpty(),
            model = savedStateHandle.get<String>(SavedKeys.MODEL).orEmpty(),
            serial = savedStateHandle.get<String>(SavedKeys.SERIAL).orEmpty(),
            siteAddress = savedStateHandle.get<String>(SavedKeys.SITE_ADDRESS).orEmpty(),
            siteLocation = savedStateHandle.get<String>(SavedKeys.SITE_LOCATION).orEmpty(),
            pickedDateMillis = savedStateHandle.get<Long>(SavedKeys.PICKED_DATE),
            siteLatitude = savedStateHandle.get<Double>(SavedKeys.SITE_LAT),
            siteLongitude = savedStateHandle.get<Double>(SavedKeys.SITE_LNG),
            issue = savedStateHandle.get<String>(SavedKeys.ISSUE).orEmpty(),
            budget = savedStateHandle.get<String>(SavedKeys.BUDGET).orEmpty(),
            photos = savedStateHandle.get<Array<String>>(SavedKeys.PHOTOS)?.toList().orEmpty(),
            // v0.3.5 fix #9 — re-hydrate engineerId from query arg or
            // SavedStateHandle (nav-args land in the handle too).
            prefilledEngineerId = savedStateHandle.get<String>(SavedKeys.ENGINEER_ID)
                ?: savedStateHandle.get<String>("engineerId"),
        )
    }

    private fun clearSavedDraft() {
        savedStateHandle.remove<String>(SavedKeys.CATEGORY)
        savedStateHandle.remove<String>(SavedKeys.URGENCY)
        savedStateHandle.remove<String>(SavedKeys.BRAND)
        savedStateHandle.remove<String>(SavedKeys.MODEL)
        savedStateHandle.remove<String>(SavedKeys.SERIAL)
        savedStateHandle.remove<String>(SavedKeys.SITE_ADDRESS)
        savedStateHandle.remove<String>(SavedKeys.SITE_LOCATION)
        savedStateHandle.remove<Long>(SavedKeys.PICKED_DATE)
        savedStateHandle.remove<Double>(SavedKeys.SITE_LAT)
        savedStateHandle.remove<Double>(SavedKeys.SITE_LNG)
        savedStateHandle.remove<String>(SavedKeys.ISSUE)
        savedStateHandle.remove<String>(SavedKeys.BUDGET)
        savedStateHandle.remove<Array<String>>(SavedKeys.PHOTOS)
        // v0.3.5 fix #9 — engineer pre-fill is one-shot per booking.
        // Don't carry it past submit so the next fresh open of the
        // form (e.g. from Home → "Request a repair") starts clean.
        savedStateHandle.remove<String>(SavedKeys.ENGINEER_ID)
    }

    private val effectChannel = kotlinx.coroutines.flow.MutableSharedFlow<Effect>(extraBufferCapacity = 4)
    val effects: kotlinx.coroutines.flow.Flow<Effect> = effectChannel

    private var userId: String? = null
    private var orgId: String? = null
    // Round 324 — hospital phone gate. Submitting a booking without
    // it leaves the engineer with no way to reach the hospital
    // (chat works, but masked-calling via request-call-session
    // returns 422 missing_phone). Cache the value at sign-in so the
    // submit gate doesn't have to fetch on every tap.
    private var hospitalPhone: String? = null

    init {
        // r516 (v0.4 P5 #10) — funnel ping when hospital opens the
        // request-service wizard. job_post_submitted already fires in
        // create().onSuccess; this captures the "started but maybe didn't
        // submit" cohort for drop-off analysis.
        analytics.track(com.equipseva.app.core.data.analytics.AnalyticsEvent.JOB_POST_STARTED)
        // v0.3.5 fix #9 — pin engineerId nav-arg into SavedKeys so a
        // process kill mid-typing recovers correctly (the original
        // nav-arg key only lives on the back-stack entry). Also kick
        // off the engineer-profile fetch for the reassurance header.
        val initialEngineerId = _state.value.prefilledEngineerId
        if (!initialEngineerId.isNullOrBlank()) {
            savedStateHandle[SavedKeys.ENGINEER_ID] = initialEngineerId
            loadEngineerReassuranceData(initialEngineerId)
        }
        // Round 471 — draft recovery. Check for an existing saved draft
        // before the user starts typing; if one exists, show the sticky
        // recovery bar so they can choose Keep / Discard. Runs once on
        // ViewModel construction (cold-start of the screen).
        // v0.3.5 fix #9 — but suppress the recovery bar when we're in
        // a re-booking flow. The user clicked "Book again" to start a
        // fresh booking for THIS engineer; a stale unrelated draft from
        // a prior session would only confuse them.
        viewModelScope.launch {
            if (initialEngineerId.isNullOrBlank()) {
                val existing = draftStore.loadDraft()
                if (existing != null) {
                    _state.update { it.copy(showDraftRecoveryBar = true) }
                }
            }
        }
        // Round 471 — auto-save every 10s of form-field activity. Debounce
        // on the user-meaningful fields only (skip transient submitting /
        // uploadingPhoto / error flags so they don't trigger spurious
        // saves). This is defense-in-depth against true process kill —
        // SavedStateHandle survives short-lived OS kills while the
        // ViewModel is still warm, this DataStore survives cold-start
        // hours / days later.
        @OptIn(FlowPreview::class)
        viewModelScope.launch {
            _state
                .map { it.draftSnapshot() }
                .distinctUntilChanged()
                .debounce(AUTO_SAVE_DEBOUNCE_MS)
                .collect { snap ->
                    // Skip empty-form snapshots — no point saving a draft
                    // the user hasn't typed anything into. The recovery
                    // bar would then appear on next launch for a blank
                    // form, which is just annoying.
                    if (snap.isEmpty()) return@collect
                    draftStore.saveDraft(snap)
                }
        }
        viewModelScope.launch {
            authRepository.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .distinctUntilChangedBy { it.userId }
                .collect { session ->
                    userId = session.userId
                    val profile = profileRepository.fetchById(session.userId).getOrNull()
                    orgId = profile?.organizationId
                    hospitalPhone = profile?.phone?.takeIf { it.isNotBlank() }
                    // v0.2.0 onboarding captures hospital state + district;
                    // pre-fill the booking form's "Where" address line so
                    // the user starts with their saved district/state and
                    // edits to add a specific landmark, instead of typing
                    // the city + state from scratch every booking. Only
                    // applied when the user hasn't already typed something
                    // (SavedStateHandle restore wins) and when both fields
                    // are present on the profile.
                    val state = profile?.state?.takeIf { it.isNotBlank() }
                    val district = profile?.district?.takeIf { it.isNotBlank() }
                    if (_state.value.siteAddress.isBlank() && state != null && district != null) {
                        val seed = "$district, $state"
                        savedStateHandle[SavedKeys.SITE_ADDRESS] = seed
                        _state.update { it.copy(siteAddress = seed) }
                    }
                }
        }
    }

    fun onCategoryChange(value: RepairEquipmentCategory) {
        savedStateHandle[SavedKeys.CATEGORY] = value.name
        _state.update { it.copy(category = value) }
    }
    fun onUrgencyChange(value: RepairJobUrgency) {
        savedStateHandle[SavedKeys.URGENCY] = value.name
        _state.update { it.copy(urgency = value) }
    }
    fun onBrandChange(value: String) {
        val capped = value.take(100)
        savedStateHandle[SavedKeys.BRAND] = capped
        _state.update { it.copy(brand = capped) }
    }
    fun onModelChange(value: String) {
        val capped = value.take(100)
        savedStateHandle[SavedKeys.MODEL] = capped
        _state.update { it.copy(model = capped) }
    }
    fun onSerialChange(value: String) {
        val capped = value.take(100)
        savedStateHandle[SavedKeys.SERIAL] = capped
        _state.update { it.copy(serial = capped) }
    }
    fun onSiteAddressChange(value: String) {
        val capped = value.take(500)
        savedStateHandle[SavedKeys.SITE_ADDRESS] = capped
        _state.update {
            it.copy(siteAddress = capped, siteAddressError = null, errorMessage = null)
        }
    }
    fun onSiteLocationChange(value: String) {
        val capped = value.take(500)
        savedStateHandle[SavedKeys.SITE_LOCATION] = capped
        _state.update { it.copy(siteLocation = capped) }
    }
    fun onPickedDateChange(value: Long?) {
        savedStateHandle[SavedKeys.PICKED_DATE] = value
        _state.update { it.copy(pickedDateMillis = value) }
    }

    /**
     * Picked from the LocationPickerMap composable. Pair of nullable doubles
     * so the map can clear the pin (passing null/null) — though today the
     * picker only emits non-null pairs.
     */
    fun onSiteCoordsChange(latitude: Double?, longitude: Double?) {
        // Reject obviously bad coordinates. A garbled callback or a future
        // hostile callsite could pass (1000, 1000) and the engineer-side
        // distance filter would silently treat the job as unreachable.
        // WGS84 ranges; NaN guard for the IEEE-754 edge.
        val latOk = latitude == null ||
            (latitude in -90.0..90.0 && !latitude.isNaN())
        val lngOk = longitude == null ||
            (longitude in -180.0..180.0 && !longitude.isNaN())
        if (!latOk || !lngOk) {
            savedStateHandle.remove<Double>(SavedKeys.SITE_LAT)
            savedStateHandle.remove<Double>(SavedKeys.SITE_LNG)
            _state.update { it.copy(siteLatitude = null, siteLongitude = null) }
            return
        }
        savedStateHandle[SavedKeys.SITE_LAT] = latitude
        savedStateHandle[SavedKeys.SITE_LNG] = longitude
        _state.update { it.copy(siteLatitude = latitude, siteLongitude = longitude) }
    }
    fun onIssueChange(value: String) {
        // Issue is the long-form bug description; 2000 char cap covers
        // the longest realistic case while preventing a 10 KB paste
        // from wedging the form submit.
        val capped = value.take(2000)
        savedStateHandle[SavedKeys.ISSUE] = capped
        _state.update {
            it.copy(issue = capped, issueError = null, errorMessage = null)
        }
    }
    fun onBudgetChange(value: String) {
        // Budget is a numeric amount typed as text (parsed later via
        // toDoubleOrNull). Cap at 12 chars — enough for "9999999999.99"
        // (10-digit rupees + 2 decimals); blocks abuse paste.
        val capped = value.take(12)
        savedStateHandle[SavedKeys.BUDGET] = capped
        _state.update {
            it.copy(budget = capped, budgetError = null, errorMessage = null)
        }
    }

    /**
     * Uploads [bytes] to the `repair-photos` bucket under the signed-in user's
     * folder and pins the resulting object path into UI state. The path is
     * passed straight into the `issue_photos` array on submit; SignedUrls can
     * be derived later for display by anyone with access to the row.
     */
    fun onPhotoPicked(fileName: String, bytes: ByteArray, contentType: String?) {
        val uid = userId
        if (uid == null) {
            viewModelScope.launch {
                effectChannel.emit(Effect.ShowMessage("Sign in again and retry"))
            }
            return
        }
        if (_state.value.uploadingPhoto) return
        _state.update { it.copy(uploadingPhoto = true) }
        val stored = "issue-${timestampedName(fileName, fallback = "photo.jpg")}"
        val path = "$uid/$stored"
        viewModelScope.launch {
            storageRepository.upload(
                bucket = StorageRepository.Buckets.REPAIR_PHOTOS,
                path = path,
                bytes = bytes,
                contentType = contentType,
            ).fold(
                onSuccess = {
                    _state.update {
                        val nextPhotos = it.photos + path
                        savedStateHandle[SavedKeys.PHOTOS] = nextPhotos.toTypedArray()
                        it.copy(
                            uploadingPhoto = false,
                            photos = nextPhotos,
                        )
                    }
                },
                onFailure = { ex ->
                    _state.update { it.copy(uploadingPhoto = false) }
                    effectChannel.emit(Effect.ShowMessage(ex.toUserMessage()))
                },
            )
        }
    }

    fun onRemovePhoto(path: String) {
        _state.update {
            val nextPhotos = it.photos - path
            savedStateHandle[SavedKeys.PHOTOS] = nextPhotos.toTypedArray()
            it.copy(photos = nextPhotos)
        }
    }

    /**
     * v0.3.5 fix #9 — fetch the engineer's public profile so the
     * reassurance header on the booking form shows their name +
     * rating + total jobs. Same RPC the EngineerPublicProfileScreen
     * uses, so a re-booking experience renders the same numbers the
     * hospital just saw on the detail screen. Soft-fail: the header
     * just stays hidden if the fetch errors, since the rest of the
     * form is fully functional without it.
     */
    private fun loadEngineerReassuranceData(engineerId: String) {
        viewModelScope.launch {
            val profile = engineerDirectoryRepository
                .fetchPublicProfile(engineerId)
                .getOrNull()
            if (profile != null) {
                _state.update {
                    it.copy(
                        prefilledEngineerName = sanitizeServerName(profile.fullName),
                        prefilledEngineerRating = profile.ratingAvg,
                        prefilledEngineerJobCount = profile.totalJobs,
                    )
                }
            }
        }
    }

    /**
     * Round 471 — "Keep" tap on draft-recovery bar. Loads the saved draft
     * from DataStore, replays it into both SavedStateHandle (so a
     * subsequent process death restores correctly) and the in-memory
     * UiState, then dismisses the recovery bar.
     */
    fun onKeepDraft() {
        viewModelScope.launch {
            val draft = draftStore.loadDraft()
            if (draft == null) {
                // Draft expired / was cleared between bar-show and tap.
                _state.update { it.copy(showDraftRecoveryBar = false) }
                return@launch
            }
            val category = RepairEquipmentCategory.fromKey(draft.category)
            val urgency = RepairJobUrgency.fromKey(draft.urgency)
            savedStateHandle[SavedKeys.CATEGORY] = category.name
            savedStateHandle[SavedKeys.URGENCY] = urgency.name
            savedStateHandle[SavedKeys.BRAND] = draft.brand
            savedStateHandle[SavedKeys.MODEL] = draft.model
            savedStateHandle[SavedKeys.SERIAL] = draft.serial
            savedStateHandle[SavedKeys.SITE_ADDRESS] = draft.siteAddress
            savedStateHandle[SavedKeys.SITE_LOCATION] = draft.siteLocation
            savedStateHandle[SavedKeys.PICKED_DATE] = draft.pickedDateMillis
            savedStateHandle[SavedKeys.SITE_LAT] = draft.siteLatitude
            savedStateHandle[SavedKeys.SITE_LNG] = draft.siteLongitude
            savedStateHandle[SavedKeys.ISSUE] = draft.issue
            savedStateHandle[SavedKeys.BUDGET] = draft.budget
            savedStateHandle[SavedKeys.PHOTOS] = draft.photoUris.toTypedArray()
            _state.update {
                it.copy(
                    category = category,
                    urgency = urgency,
                    brand = draft.brand,
                    model = draft.model,
                    serial = draft.serial,
                    siteAddress = draft.siteAddress,
                    siteLocation = draft.siteLocation,
                    pickedDateMillis = draft.pickedDateMillis,
                    siteLatitude = draft.siteLatitude,
                    siteLongitude = draft.siteLongitude,
                    issue = draft.issue,
                    budget = draft.budget,
                    photos = draft.photoUris,
                    showDraftRecoveryBar = false,
                )
            }
        }
    }

    /**
     * Round 471 — "Discard" tap on draft-recovery bar. Wipes the stored
     * draft and dismisses the bar; the form remains at its (already
     * blank) initial state so the user starts fresh.
     */
    fun onDiscardDraft() {
        viewModelScope.launch {
            draftStore.clearDraft()
            _state.update { it.copy(showDraftRecoveryBar = false) }
        }
    }

    fun onSubmit(selectedSlot: Int = -1) {
        val uid = userId
        if (uid == null) {
            _state.update { it.copy(errorMessage = "Sign in again and retry.") }
            return
        }
        // Round 324 — gate on hospital phone. Without it, the engineer
        // accepts the bid and tries to call but request-call-session
        // returns 422 missing_phone. The error is more recoverable at
        // booking time (hospital → AddPhone) than at call time
        // (engineer can't unblock themselves). Mirror the existing
        // "Pick a time slot" / "Issue too short" gate UX.
        if (hospitalPhone.isNullOrBlank()) {
            val msg = "Add your phone number on Profile → Phone number before posting a job — engineers need it to coordinate the visit."
            _state.update { it.copy(errorMessage = msg) }
            effectChannel.tryEmit(Effect.ShowMessage(msg))
            return
        }
        // Block submit when no slot is picked. Earlier code happily wrote
        // a job with scheduledDate=null + scheduledTimeSlot=null, which
        // engineers couldn't filter on and hospital later couldn't tell
        // why the bid feed was quiet.
        if (selectedSlot < 0) {
            _state.update { it.copy(errorMessage = "Pick when the engineer should come.") }
            return
        }
        val current = _state.value
        val issue = current.issue.trim()
        if (issue.length < 10) {
            // Issue lives on step 1, but Submit is on step 4 — without
            // surfacing the message at top-level the user just sees the
            // button do nothing. Mirror it into errorMessage (the banner
            // is rendered above every step) and emit a snackbar so the
            // failure is unmissable.
            val msg = "Please describe the issue (10 characters or more) on the Issue step."
            _state.update {
                it.copy(
                    issueError = "Please describe the issue (10 characters or more).",
                    errorMessage = msg,
                )
            }
            effectChannel.tryEmit(Effect.ShowMessage(msg))
            return
        }
        // Require a non-trivial site address OR map coordinates. Without
        // one, the engineer has no way to reach the hospital and the
        // job lands in their feed as an unactionable row. Map pin alone
        // isn't a substitute — engineers need a typed address for the
        // navigation app handoff. 5-char floor blocks accidental "a"
        // submits without enforcing a specific format.
        val address = current.siteAddress.trim()
        if (address.length < 5) {
            val msg = "Add the service address (5 characters or more) on the Where step."
            _state.update {
                it.copy(
                    siteAddressError = "Address is required so engineers can reach you.",
                    errorMessage = msg,
                )
            }
            effectChannel.tryEmit(Effect.ShowMessage(msg))
            return
        }
        val budgetText = current.budget.trim()
        val estimatedCost: Double? = if (budgetText.isBlank()) {
            null
        } else {
            val parsed = budgetText.toDoubleOrNull()
            if (parsed == null || parsed <= 0.0) {
                _state.update { it.copy(budgetError = "Enter a valid amount.") }
                return
            }
            parsed
        }
        // Booking scheduled_date is anchored to the hospital's local
        // time (IST); a device on UTC would otherwise compute "today"
        // 5.5h behind and submit a date the hospital wouldn't recognise.
        val today = LocalDate.now(ZoneId.of("Asia/Kolkata"))
        val (scheduledDate, scheduledTimeSlot) = resolveScheduledSlot(
            selectedSlot = selectedSlot,
            today = today,
            pickedDateMillis = current.pickedDateMillis,
        )
        _state.update { it.copy(submitting = true, errorMessage = null) }
        viewModelScope.launch {
            val draft = RepairJobDraft(
                hospitalUserId = uid,
                hospitalOrgId = orgId,
                issueDescription = issue,
                equipmentCategory = current.category,
                equipmentBrand = current.brand.trim().ifBlank { null },
                equipmentModel = current.model.trim().ifBlank { null },
                equipmentSerial = current.serial.trim().ifBlank { null },
                siteLocation = composeSiteLocation(current.siteAddress, current.siteLocation),
                siteLatitude = current.siteLatitude,
                siteLongitude = current.siteLongitude,
                issuePhotos = current.photos,
                urgency = current.urgency.takeIf { it != RepairJobUrgency.Unknown } ?: RepairJobUrgency.Scheduled,
                scheduledDate = scheduledDate,
                scheduledTimeSlot = scheduledTimeSlot,
                estimatedCostRupees = estimatedCost,
            )
            jobRepository.create(draft)
                .onSuccess { job ->
                    clearSavedDraft()
                    // Round 471 — clear persistent draft on successful
                    // submit so the user doesn't see a stale recovery
                    // bar for a job they already created.
                    draftStore.clearDraft()
                    _state.update { UiState() }
                    // r513 (v0.4 P5 #10) — funnel ping after server-write succeeded.
                    analytics.track(
                        com.equipseva.app.core.data.analytics.AnalyticsEvent.JOB_POST_SUBMITTED,
                        mapOf(
                            "category" to current.category.storageKey,
                            "urgency" to current.urgency.storageKey,
                        ),
                    )
                    effectChannel.tryEmit(Effect.Submitted(jobId = job.id, jobNumber = job.jobNumber))
                }
                .onFailure { error ->
                    // Report the raw failure (PII-scrubbed) so a hospital that
                    // CAN'T post jobs is visible to the team — the friendly
                    // toUserMessage() ("Something went wrong") otherwise hides
                    // org-linkage RLS rejections and other systemic failures on
                    // the core revenue path, and "try again" won't help them.
                    crashReporter.report(error, "repair job post failed")
                    _state.update { it.copy(submitting = false, errorMessage = error.toUserMessage()) }
                }
        }
    }

    /**
     * Project [UiState] to a [RequestServiceFormDraft] for persistence.
     * Strips transient flags (submitting, uploadingPhoto, error fields,
     * showDraftRecoveryBar) so distinctUntilChanged() doesn't trip on
     * those and trigger spurious auto-saves.
     */
    private fun UiState.draftSnapshot(): RequestServiceFormDraft = RequestServiceFormDraft(
        category = category.storageKey,
        urgency = urgency.storageKey,
        brand = brand,
        model = model,
        serial = serial,
        siteAddress = siteAddress,
        siteLocation = siteLocation,
        pickedDateMillis = pickedDateMillis,
        siteLatitude = siteLatitude,
        siteLongitude = siteLongitude,
        issue = issue,
        budget = budget,
        photoUris = photos,
    )

    /**
     * True when the draft is essentially blank (no user input). Used to
     * skip persisting empty drafts which would otherwise pop a useless
     * recovery prompt on next launch. Auto-prefilled siteAddress (from
     * profile state/district) is not counted as user input here.
     */
    private fun RequestServiceFormDraft.isEmpty(): Boolean =
        brand.isBlank() &&
            model.isBlank() &&
            serial.isBlank() &&
            siteLocation.isBlank() &&
            issue.isBlank() &&
            budget.isBlank() &&
            photoUris.isEmpty() &&
            pickedDateMillis == null &&
            siteLatitude == null &&
            siteLongitude == null

    private companion object {
        // 10 seconds — matches the plan; long enough that we're not
        // hammering DataStore on every keystroke, short enough that a
        // process kill loses at most ~10s of typing.
        const val AUTO_SAVE_DEBOUNCE_MS = 10_000L
    }
}

/**
 * Compose the repair-job `site_location` text from the request-form's
 * two location fields. Output shape:
 *
 *   - both present  → "Address: ${addr}\nNotes: ${notes}"
 *   - only address  → "Address: ${addr}"
 *   - only notes    → "Notes: ${notes}"
 *   - both blank    → null
 *
 * Both fields are trimmed before composition, and entirely blank
 * inputs fold out of the listOfNotNull so the composed string never
 * carries a label without a value.
 */
internal fun composeSiteLocation(siteAddress: String, siteNotes: String): String? =
    listOfNotNull(
        siteAddress.trim().ifBlank { null }?.let { "Address: $it" },
        siteNotes.trim().ifBlank { null }?.let { "Notes: $it" },
    ).joinToString("\n").ifBlank { null }

/**
 * Resolves the request-service form's slot picker into a
 * (scheduledDate, scheduledTimeSlot) pair anchored to IST. Five slots:
 *   * 0 → today, "evening"
 *   * 1 → tomorrow, "morning"
 *   * 2 → tomorrow, "afternoon"
 *   * 3 → flexible (null date, "flexible" slot — user opted for any time)
 *   * 4 → custom calendar pick. Uses [pickedDateMillis] (Instant epoch
 *     ms from the date picker); resolves to that date in IST with
 *     "any" slot. Falls back to (null, null) when the user tapped the
 *     calendar tile but didn't pick a date.
 *   * any other value → (null, null) (no selection).
 *
 * Extracted from RequestServiceViewModel.onSubmit so the date arithmetic
 * + IST anchoring can be unit-tested deterministically.
 */
internal fun resolveScheduledSlot(
    selectedSlot: Int,
    today: LocalDate,
    pickedDateMillis: Long?,
): Pair<String?, String?> = when (selectedSlot) {
    0 -> today.toString() to "evening"
    1 -> today.plusDays(1).toString() to "morning"
    2 -> today.plusDays(1).toString() to "afternoon"
    3 -> null to "flexible"
    4 -> {
        if (pickedDateMillis != null) {
            // Pin to IST so the date the hospital sees in the picker
            // matches the date persisted server-side, independent of
            // device time zone (round 237).
            val picked = java.time.Instant.ofEpochMilli(pickedDateMillis)
                .atZone(java.time.ZoneId.of("Asia/Kolkata")).toLocalDate()
            picked.toString() to "any"
        } else {
            null to null
        }
    }
    else -> null to null
}
