package com.equipseva.app.features.hospital

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
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
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.ZoneId
import java.util.UUID
import javax.inject.Inject

@HiltViewModel
class RequestServiceViewModel @Inject constructor(
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
        const val OWNER_ID = "req.ownerId"
        const val SESSION_ID = "req.sessionId"
        const val RECOVERY_PENDING = "req.recoveryPending"
        const val SELECTED_SLOT = "req.selectedSlot"
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

    // ActivityResult transport correlation outlives the form/account. Keep it
    // separate from draft fields until the external result is actually drained.
    private object PhotoKeys {
        const val ID = "reqPhoto.id"
        const val KIND = "reqPhoto.kind"
        const val OWNER = "reqPhoto.owner"
        const val SESSION = "reqPhoto.session"
        const val INVALIDATED = "reqPhoto.invalidated"
    }

    data class UiState(
        val formSession: RequestServiceDraftStore.Lease? = null,
        val selectedSlot: Int = -1,
        // r1496 — default must be a v0.4-SERVICEABLE category. The old default
        // (ImagingRadiology) is allowed_in_v04=false server-side, so a hospital
        // who kept the pre-selected chip had their post hard-rejected by the
        // repair_jobs taxonomy gate every time.
        val category: RepairEquipmentCategory = RepairEquipmentCategory.PatientMonitoring,
        // Categories offered by the picker — the static mirror of the server
        // taxonomy (allowed_in_v04 = true). See RepairEquipmentCategory.V04_ALLOWED.
        val allowedCategories: List<RepairEquipmentCategory> =
            RepairEquipmentCategory.V04_ALLOWED,
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
        val checkingDraftRecovery: Boolean = false,
        val draftFailure: DraftFailure? = null,
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

    enum class DraftFailure { Check, Restore, Discard, Save }
    enum class PhotoOperation { CameraPermission, Camera, Gallery }

    sealed interface Effect {
        val formSession: RequestServiceDraftStore.Lease
        data class Submitted(val jobId: String, val jobNumber: String?, override val formSession: RequestServiceDraftStore.Lease) : Effect
        data class ShowMessage(val text: String, override val formSession: RequestServiceDraftStore.Lease) : Effect
        data class RetryPhotoSelection(override val formSession: RequestServiceDraftStore.Lease) : Effect
    }

    // Restored values stay hidden until their owner AND login session match.
    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private fun restoredInitialState(): UiState {
        val category = savedStateHandle.get<String>(SavedKeys.CATEGORY)
            ?.let { name -> runCatching { RepairEquipmentCategory.valueOf(name) }.getOrNull() }
            ?: RepairEquipmentCategory.PatientMonitoring
        val urgency = savedStateHandle.get<String>(SavedKeys.URGENCY)
            ?.let { name -> runCatching { RepairJobUrgency.valueOf(name) }.getOrNull() }
            ?: RepairJobUrgency.Scheduled
        return UiState(
            selectedSlot = savedStateHandle.get<Int>(SavedKeys.SELECTED_SLOT) ?: -1,
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
        savedStateHandle.remove<String>(SavedKeys.OWNER_ID)
        savedStateHandle.remove<String>(SavedKeys.SESSION_ID)
        savedStateHandle.remove<Boolean>(SavedKeys.RECOVERY_PENDING)
        savedStateHandle.remove<Int>(SavedKeys.SELECTED_SLOT)
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
    private var draftSession: RequestServiceDraftStore.Lease? = null
    private var hasBoundSession = false
    private data class PendingPhotoOperation(
        val id: String,
        val kind: PhotoOperation,
        val ownerId: String,
        val sessionId: String?,
        val lease: RequestServiceDraftStore.Lease? = null,
        val invalidated: Boolean = false,
    )
    private var pendingPhotoOperation: PendingPhotoOperation? = restoredPhotoOperation()
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
        viewModelScope.launch {
            draftStore.activeSession.collect { lease ->
                if (lease == draftSession) return@collect
                if (hasBoundSession) {
                    // The root navigation can miss a transient auth boundary while
                    // backgrounded. Reuse this VM safely with a blank scoped form;
                    // every old operation and rendered callback keeps its old lease.
                    draftSession = null
                    userId = null
                    orgId = null
                    hospitalPhone = null
                    pendingPhotoOperation?.let {
                        pendingPhotoOperation = it.copy(invalidated = true)
                        savedStateHandle[PhotoKeys.INVALIDATED] = true
                    }
                    clearSavedDraft()
                    savedStateHandle.remove<String>("engineerId")
                    _state.value = UiState()
                }
                if (lease != null && draftStore.isCurrent(lease)) {
                    hasBoundSession = true
                    bindDraftSession(lease)
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
                .map {
                    DraftSave(
                        draftSession,
                        it.draftSnapshot(),
                        it.recoveryPending(),
                        draftSession?.let(draftStore::writeEpoch),
                    )
                }
                .distinctUntilChanged()
                .debounce(AUTO_SAVE_DEBOUNCE_MS)
                .collect { snap ->
                    // Skip empty-form snapshots — no point saving a draft
                    // the user hasn't typed anything into. The recovery
                    // bar would then appear on next launch for a blank
                    // form, which is just annoying.
                    val lease = snap.lease ?: return@collect
                    if (snap.recoveryPending || _state.value.recoveryPending() ||
                        snap.draft.isEmpty() || !isCurrent(lease)
                    ) return@collect
                    saveSnapshot(lease, snap.draft, snap.writeEpoch)
                }
        }
    }

    private data class DraftSave(
        val lease: RequestServiceDraftStore.Lease?,
        val draft: RequestServiceFormDraft,
        val recoveryPending: Boolean,
        val writeEpoch: String?,
    )

    private fun isCurrent(lease: RequestServiceDraftStore.Lease): Boolean =
        draftSession == lease && draftStore.isCurrent(lease)

    private fun currentDraftSession(): RequestServiceDraftStore.Lease? =
        draftSession?.takeIf(::isCurrent)

    /** The caller captures this lease when rendering a control or launching a picker. */
    fun forFormSession(lease: RequestServiceDraftStore.Lease?, action: RequestServiceViewModel.() -> Unit) {
        if (lease != null && isCurrent(lease)) action()
    }

    private fun restoredPhotoOperation(): PendingPhotoOperation? {
        val id = savedStateHandle.get<String>(PhotoKeys.ID)?.takeIf { it.isNotBlank() } ?: return null
        val owner = savedStateHandle.get<String>(PhotoKeys.OWNER)?.takeIf { it.isNotBlank() } ?: return null
        val kind = savedStateHandle.get<String>(PhotoKeys.KIND)
            ?.let { runCatching { PhotoOperation.valueOf(it) }.getOrNull() } ?: return null
        return PendingPhotoOperation(id, kind, owner, savedStateHandle.get<String>(PhotoKeys.SESSION),
            invalidated = savedStateHandle.get<Boolean>(PhotoKeys.INVALIDATED) == true)
    }

    private fun clearPhotoOperation() {
        pendingPhotoOperation = null
        savedStateHandle.remove<String>(PhotoKeys.ID)
        savedStateHandle.remove<String>(PhotoKeys.KIND)
        savedStateHandle.remove<String>(PhotoKeys.OWNER)
        savedStateHandle.remove<String>(PhotoKeys.SESSION)
        savedStateHandle.remove<Boolean>(PhotoKeys.INVALIDATED)
    }

    /** One external launch at a time, including an old account's undrained result. */
    fun launchPhotoOperation(
        lease: RequestServiceDraftStore.Lease?,
        kind: PhotoOperation,
        launch: () -> Unit,
    ): Boolean {
        if (lease == null || !isCurrent(lease) || pendingPhotoOperation != null) return false
        val operation = PendingPhotoOperation(UUID.randomUUID().toString(), kind, lease.identity.ownerId, lease.identity.sessionId, lease)
        pendingPhotoOperation = operation
        savedStateHandle[PhotoKeys.ID] = operation.id
        savedStateHandle[PhotoKeys.KIND] = operation.kind.name
        savedStateHandle[PhotoKeys.OWNER] = operation.ownerId
        savedStateHandle[PhotoKeys.SESSION] = operation.sessionId
        savedStateHandle[PhotoKeys.INVALIDATED] = false
        return try {
            launch()
            true
        } catch (error: Exception) {
            clearPhotoOperation()
            if (error is kotlinx.coroutines.CancellationException) throw error
            crashReporter.report(error, "request photo picker launch failed")
            effectChannel.tryEmit(Effect.ShowMessage(error.toUserMessage(), lease))
            false
        }
    }

    /**
     * A recreated Activity may deliver a result before auth initialization.
     * Wait for the verified owner/session bind, then consume that operation
     * once. A stale operation is drained, never relabeled as the current one.
     */
    fun onPhotoOperationResult(kind: PhotoOperation, result: (RequestServiceDraftStore.Lease) -> Unit) {
        val operation = pendingPhotoOperation?.takeIf { it.kind == kind } ?: return
        viewModelScope.launch {
            if (!hasBoundSession) state.first { it.formSession != null }
            val resolved = pendingPhotoOperation?.takeIf { it.id == operation.id } ?: return@launch
            clearPhotoOperation()
            val lease = resolved.lease
            if (!resolved.invalidated && lease != null && isCurrent(lease)) {
                result(lease)
            } else if (resolved.sessionId == null) {
                // Unsupported session claims cannot prove a process-restored
                // picker result's owner. Same-account UI gets an explicit retry.
                currentDraftSession()?.takeIf { it.identity.ownerId == resolved.ownerId }?.let {
                    effectChannel.tryEmit(Effect.RetryPhotoSelection(it))
                }
            }
        }
    }

    private fun UiState.recoveryPending(): Boolean = showDraftRecoveryBar || checkingDraftRecovery ||
        (draftFailure != null && draftFailure != DraftFailure.Save)

    private suspend fun saveSnapshot(
        lease: RequestServiceDraftStore.Lease,
        draft: RequestServiceFormDraft,
        writeEpoch: String?,
    ) {
        try {
            draftStore.saveDraft(lease, draft, writeEpoch)
            if (isCurrent(lease) && _state.value.draftFailure == DraftFailure.Save) {
                _state.update { it.copy(draftFailure = null) }
            }
        } catch (error: Exception) {
            if (error is kotlinx.coroutines.CancellationException) throw error
            crashReporter.report(error, "request draft autosave failed")
            if (isCurrent(lease)) _state.update { it.copy(draftFailure = DraftFailure.Save) }
        }
    }

    fun onRetryDraftOperation() {
        val lease = currentDraftSession() ?: return
        if (_state.value.checkingDraftRecovery) return
        when (_state.value.draftFailure) {
            DraftFailure.Check -> checkDraftRecovery(lease)
            DraftFailure.Restore -> onKeepDraft()
            DraftFailure.Discard -> onDiscardDraft()
            DraftFailure.Save -> {
                val current = _state.value
                val epoch = draftStore.writeEpoch(lease)
                viewModelScope.launch { saveSnapshot(lease, current.draftSnapshot(), epoch) }
            }
            null -> Unit
        }
    }

    private fun checkDraftRecovery(lease: RequestServiceDraftStore.Lease) {
        savedStateHandle[SavedKeys.RECOVERY_PENDING] = true
        _state.update { it.copy(checkingDraftRecovery = true, draftFailure = null) }
        val recoveryEpoch = draftStore.writeEpoch(lease)
        viewModelScope.launch {
            try {
                val existing = draftStore.loadDraft(lease)
                if (isCurrent(lease) && draftStore.writeEpoch(lease) == recoveryEpoch) {
                    savedStateHandle[SavedKeys.RECOVERY_PENDING] = existing != null
                    _state.update { it.copy(showDraftRecoveryBar = existing != null, checkingDraftRecovery = false) }
                }
            } catch (error: Exception) {
                if (error is kotlinx.coroutines.CancellationException) throw error
                crashReporter.report(error, "request draft recovery failed")
                if (isCurrent(lease) && draftStore.writeEpoch(lease) == recoveryEpoch) {
                    _state.update { it.copy(checkingDraftRecovery = false, draftFailure = DraftFailure.Check) }
                }
            }
        }
    }

    private fun bindDraftSession(lease: RequestServiceDraftStore.Lease) {
        draftSession = lease
        userId = lease.identity.ownerId
        val savedOwner = savedStateHandle.get<String>(SavedKeys.OWNER_ID)
        val savedSession = savedStateHandle.get<String>(SavedKeys.SESSION_ID)
        val canRestore = lease.identity.sessionId != null && savedOwner == lease.identity.ownerId &&
            savedSession == lease.identity.sessionId
        val recoveryUnresolved = canRestore && savedStateHandle.get<Boolean>(SavedKeys.RECOVERY_PENDING) == true
        // A fresh nav argument is safe only when the handle has no draft fields.
        val freshRoute = savedOwner == null && savedStateHandle.keys().none { it.startsWith("req.") }
        val freshEngineerId = if (freshRoute) savedStateHandle.get<String>("engineerId") else null
        if (!canRestore) {
            clearSavedDraft()
            savedStateHandle.remove<String>("engineerId")
        }
        savedStateHandle[SavedKeys.OWNER_ID] = lease.identity.ownerId
        savedStateHandle[SavedKeys.SESSION_ID] = lease.identity.sessionId
        pendingPhotoOperation?.takeIf { it.lease == null && !it.invalidated }?.let {
            if (it.sessionId != null && it.ownerId == lease.identity.ownerId && it.sessionId == lease.identity.sessionId) {
                pendingPhotoOperation = it.copy(lease = lease)
            } else {
                pendingPhotoOperation = it.copy(invalidated = true)
                savedStateHandle[PhotoKeys.INVALIDATED] = true
            }
        }
        _state.value = (if (canRestore) restoredInitialState() else UiState(prefilledEngineerId = freshEngineerId))
            .copy(formSession = lease)
        val initialEngineerId = _state.value.prefilledEngineerId
        if (!initialEngineerId.isNullOrBlank()) {
            savedStateHandle[SavedKeys.ENGINEER_ID] = initialEngineerId
            loadEngineerReassuranceData(initialEngineerId, lease)
        }
        // Same-session form state does not imply the user resolved the persistent
        // draft prompt. Preserve that decision across recreation, including a
        // process death while the initial disk read was still pending.
        if ((!canRestore || recoveryUnresolved) && initialEngineerId.isNullOrBlank()) {
            checkDraftRecovery(lease)
        }
        viewModelScope.launch {
            val profile = profileRepository.fetchById(lease.identity.ownerId).getOrNull()
            if (!isCurrent(lease)) return@launch
            orgId = profile?.organizationId
            hospitalPhone = profile?.phone?.takeIf { it.isNotBlank() }
            // Existing same-session state wins over profile location autofill.
            val state = profile?.state?.takeIf { it.isNotBlank() }
            val district = profile?.district?.takeIf { it.isNotBlank() }
            if (_state.value.siteAddress.isBlank() && state != null && district != null) {
                val seed = "$district, $state"
                savedStateHandle[SavedKeys.SITE_ADDRESS] = seed
                _state.update { it.copy(siteAddress = seed) }
            }
        }
    }

    fun onSelectedSlotChange(value: Int) {
        if (currentDraftSession() == null) return
        savedStateHandle[SavedKeys.SELECTED_SLOT] = value
        _state.update { it.copy(selectedSlot = value) }
    }

    fun onCategoryChange(value: RepairEquipmentCategory) {
        if (currentDraftSession() == null) return
        savedStateHandle[SavedKeys.CATEGORY] = value.name
        _state.update { it.copy(category = value) }
    }
    fun onUrgencyChange(value: RepairJobUrgency) {
        if (currentDraftSession() == null) return
        savedStateHandle[SavedKeys.URGENCY] = value.name
        _state.update { it.copy(urgency = value) }
    }
    fun onBrandChange(value: String) {
        if (currentDraftSession() == null) return
        val capped = value.take(100)
        savedStateHandle[SavedKeys.BRAND] = capped
        _state.update { it.copy(brand = capped) }
    }
    fun onModelChange(value: String) {
        if (currentDraftSession() == null) return
        val capped = value.take(100)
        savedStateHandle[SavedKeys.MODEL] = capped
        _state.update { it.copy(model = capped) }
    }
    fun onSerialChange(value: String) {
        if (currentDraftSession() == null) return
        val capped = value.take(100)
        savedStateHandle[SavedKeys.SERIAL] = capped
        _state.update { it.copy(serial = capped) }
    }
    fun onSiteAddressChange(value: String) {
        if (currentDraftSession() == null) return
        val capped = value.take(500)
        savedStateHandle[SavedKeys.SITE_ADDRESS] = capped
        _state.update {
            it.copy(siteAddress = capped, siteAddressError = null, errorMessage = null)
        }
    }
    fun onSiteLocationChange(value: String) {
        if (currentDraftSession() == null) return
        val capped = value.take(500)
        savedStateHandle[SavedKeys.SITE_LOCATION] = capped
        _state.update { it.copy(siteLocation = capped) }
    }
    fun onPickedDateChange(value: Long?) {
        if (currentDraftSession() == null) return
        savedStateHandle[SavedKeys.PICKED_DATE] = value
        _state.update { it.copy(pickedDateMillis = value) }
    }

    /**
     * Picked from the LocationPickerMap composable. Pair of nullable doubles
     * so the map can clear the pin (passing null/null) — though today the
     * picker only emits non-null pairs.
     */
    fun onSiteCoordsChange(latitude: Double?, longitude: Double?) {
        if (currentDraftSession() == null) return
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
        if (currentDraftSession() == null) return
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
        if (currentDraftSession() == null) return
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
        val lease = currentDraftSession() ?: return
        val uid = userId
        if (uid == null) {
            viewModelScope.launch {
                effectChannel.emit(Effect.ShowMessage("Sign in again and retry", lease))
            }
            return
        }
        if (_state.value.uploadingPhoto) return
        _state.update { it.copy(uploadingPhoto = true) }
        val stored = "issue-${timestampedName(fileName, fallback = "photo.jpg")}"
        val path = "$uid/$stored"
        viewModelScope.launch {
            if (!isCurrent(lease)) return@launch
            storageRepository.upload(
                bucket = StorageRepository.Buckets.REPAIR_PHOTOS,
                path = path,
                bytes = bytes,
                contentType = contentType,
            ).fold(
                onSuccess = {
                    if (!isCurrent(lease)) return@fold
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
                    if (!isCurrent(lease)) return@fold
                    _state.update { it.copy(uploadingPhoto = false) }
                    effectChannel.emit(Effect.ShowMessage(ex.toUserMessage(), lease))
                },
            )
        }
    }

    fun onRemovePhoto(path: String) {
        if (currentDraftSession() == null) return
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
    private fun loadEngineerReassuranceData(
        engineerId: String,
        lease: RequestServiceDraftStore.Lease,
    ) {
        viewModelScope.launch {
            if (!isCurrent(lease)) return@launch
            val profile = engineerDirectoryRepository
                .fetchPublicProfile(engineerId)
                .getOrNull()
            if (profile != null && isCurrent(lease)) {
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
        val lease = currentDraftSession() ?: return
        if (_state.value.checkingDraftRecovery) return
        val recoveryEpoch = draftStore.writeEpoch(lease)
        _state.update { it.copy(checkingDraftRecovery = true, draftFailure = null) }
        viewModelScope.launch {
            try {
                val draft = draftStore.loadDraft(lease)
                if (!isCurrent(lease) || draftStore.writeEpoch(lease) != recoveryEpoch) return@launch
                savedStateHandle[SavedKeys.RECOVERY_PENDING] = false
                if (draft == null) {
                    // Draft expired / was cleared between bar-show and tap.
                    _state.update { it.copy(showDraftRecoveryBar = false, checkingDraftRecovery = false) }
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
                savedStateHandle[SavedKeys.SELECTED_SLOT] = draft.selectedSlot
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
                        selectedSlot = draft.selectedSlot,
                        showDraftRecoveryBar = false,
                        checkingDraftRecovery = false,
                    )
                }
            } catch (error: Exception) {
                if (error is kotlinx.coroutines.CancellationException) throw error
                crashReporter.report(error, "request draft restore failed")
                if (isCurrent(lease) && draftStore.writeEpoch(lease) == recoveryEpoch) {
                    _state.update { it.copy(checkingDraftRecovery = false, draftFailure = DraftFailure.Restore) }
                }
            }
        }
    }

    /**
     * Round 471 — "Discard" tap on draft-recovery bar. Wipes the stored
     * draft and dismisses the bar; the form remains at its (already
     * blank) initial state so the user starts fresh.
     */
    fun onDiscardDraft() {
        val lease = currentDraftSession() ?: return
        if (_state.value.checkingDraftRecovery) return
        _state.update { it.copy(checkingDraftRecovery = true, draftFailure = null) }
        viewModelScope.launch {
            try {
                draftStore.clearDraft(lease)
                if (!isCurrent(lease)) return@launch
                savedStateHandle[SavedKeys.RECOVERY_PENDING] = false
                _state.update { it.copy(showDraftRecoveryBar = false, checkingDraftRecovery = false) }
            } catch (error: Exception) {
                if (error is kotlinx.coroutines.CancellationException) throw error
                crashReporter.report(error, "request draft discard failed")
                if (isCurrent(lease)) {
                    _state.update { it.copy(checkingDraftRecovery = false, draftFailure = DraftFailure.Discard) }
                }
            }
        }
    }

    fun onSubmit(selectedSlot: Int = -1) {
        val lease = currentDraftSession() ?: return
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
            effectChannel.tryEmit(Effect.ShowMessage(msg, lease))
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
            effectChannel.tryEmit(Effect.ShowMessage(msg, lease))
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
            effectChannel.tryEmit(Effect.ShowMessage(msg, lease))
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
            if (!isCurrent(lease)) return@launch
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
                    if (!isCurrent(lease)) return@onSuccess
                    clearSavedDraft()
                    _state.value = UiState()
                    // Round 471 — clear persistent draft on successful
                    // submit so the user doesn't see a stale recovery
                    // bar for a job they already created.
                    try {
                        draftStore.clearDraft(lease)
                    } catch (error: Exception) {
                        if (error is kotlinx.coroutines.CancellationException) throw error
                        // The server already created the job. A local cleanup
                        // failure must not turn it into a failed submission or
                        // encourage another tap that creates a duplicate job.
                        crashReporter.report(error, "submitted request draft cleanup failed")
                    }
                    if (!isCurrent(lease)) return@onSuccess
                    // r513 (v0.4 P5 #10) — funnel ping after server-write succeeded.
                    analytics.track(
                        com.equipseva.app.core.data.analytics.AnalyticsEvent.JOB_POST_SUBMITTED,
                        mapOf(
                            "category" to current.category.storageKey,
                            "urgency" to current.urgency.storageKey,
                        ),
                    )
                    effectChannel.tryEmit(Effect.Submitted(jobId = job.id, jobNumber = job.jobNumber, formSession = lease))
                }
                .onFailure { error ->
                    if (!isCurrent(lease)) return@onFailure
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
        selectedSlot = selectedSlot,
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
            selectedSlot < 0 &&
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
