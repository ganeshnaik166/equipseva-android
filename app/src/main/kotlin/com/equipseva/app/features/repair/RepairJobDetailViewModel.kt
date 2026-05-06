package com.equipseva.app.features.repair

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.chat.ChatRepository
import com.equipseva.app.core.data.dao.OutboxDao
import com.equipseva.app.core.data.engineers.EngineerRepository
import com.equipseva.app.core.data.moderation.ContentReportReason
import com.equipseva.app.core.data.moderation.ContentReportRepository
import com.equipseva.app.core.data.moderation.ContentReportTarget
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.data.repair.JobStatusPayload
import com.equipseva.app.core.data.repair.RatingRole
import com.equipseva.app.core.data.repair.RepairBid
import com.equipseva.app.core.data.repair.RepairBidPayload
import com.equipseva.app.core.data.repair.RepairBidRepository
import com.equipseva.app.core.data.repair.RepairBidStatus
import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobRepository
import com.equipseva.app.core.data.escrow.RepairJobEscrowRepository
import com.equipseva.app.core.data.repair.RepairJobUrgency
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.core.data.servicereport.ServiceReportRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.storage.StorageRepository
import com.equipseva.app.core.sync.OutboxEnqueuer
import com.equipseva.app.core.sync.OutboxKinds
import com.equipseva.app.core.sync.handlers.PhotoUploadPayload
import com.equipseva.app.core.sync.handlers.PhotoUploadStash
import com.equipseva.app.navigation.Routes
import java.time.Instant
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import javax.inject.Inject

@HiltViewModel
class RepairJobDetailViewModel @Inject constructor(
    savedState: SavedStateHandle,
    private val app: android.app.Application,
    private val jobRepository: RepairJobRepository,
    private val bidRepository: RepairBidRepository,
    private val chatRepository: ChatRepository,
    private val authRepository: AuthRepository,
    private val engineerRepository: EngineerRepository,
    private val profileRepository: ProfileRepository,
    private val userPrefs: com.equipseva.app.core.data.prefs.UserPrefs,
    private val outboxEnqueuer: OutboxEnqueuer,
    private val outboxDao: OutboxDao,
    private val reportRepository: ContentReportRepository,
    private val photoUploadStash: PhotoUploadStash,
    private val storageRepository: StorageRepository,
    private val costRevisionRepository: com.equipseva.app.core.data.repair.CostRevisionRepository,
    private val serviceReportRepository: ServiceReportRepository,
    private val escrowRepository: RepairJobEscrowRepository,
    private val json: Json,
) : ViewModel() {

    sealed interface Effect {
        data class NavigateToChat(val conversationId: String) : Effect
        // PR-D3: open the freshly-generated service report HTML in the
        // user's browser. URL is a 30-day signed Supabase Storage URL.
        data class OpenServiceReport(val url: String) : Effect
    }

    /**
     * Which side of the job the signed-in user is on. Drives which CTAs the
     * detail screen surfaces (engineer sees check-in/mark-done; hospital sees
     * the rating card after completion).
     */
    enum class ViewerRole { Engineer, Hospital, Other }

    data class RepairJobDetailUiState(
        val loading: Boolean = true,
        val job: RepairJob? = null,
        val notFound: Boolean = false,
        val errorMessage: String? = null,
        val ownBid: RepairBid? = null,
        val placingBid: Boolean = false,
        val withdrawingBid: Boolean = false,
        val bidComposerOpen: Boolean = false,
        val openingChat: Boolean = false,
        val viewerRole: ViewerRole = ViewerRole.Other,
        val updatingStatus: Boolean = false,
        val submittingRating: Boolean = false,
        /**
         * Every bid visible to the current viewer. Engineers see a list of
         * length 0..1 (RLS hides other engineers' bids). Hospitals see the
         * full set and can pick a winner via [acceptBid].
         */
        val bids: List<RepairBid> = emptyList(),
        /** Bid id currently being accepted; used to disable UI while the RPC is in-flight. */
        val acceptingBidId: String? = null,
        /**
         * Map of engineer user id → display name, populated lazily for the
         * hospital viewer so each bid row can show who placed it.
         */
        val engineerNames: Map<String, String> = emptyMap(),
        /**
         * Display name of the hospital/requester, shown on the banner so the
         * engineer knows who posted the job before bidding.
         */
        val hospitalName: String? = null,
        /**
         * "City, State" for the hospital's organization — shown next to the
         * name so an engineer can judge travel distance before bidding.
         */
        val hospitalLocation: String? = null,
        /** Count of queued bid writes waiting on the outbox to drain. */
        val queuedBidCount: Int = 0,
        /** Count of queued status transitions waiting on the outbox to drain. */
        val queuedStatusCount: Int = 0,
        val reportingTargetId: String? = null,
        val submittingReport: Boolean = false,
        // PR-D3 — generate-service-report edge function call in flight.
        val generatingServiceReport: Boolean = false,
        // PR-D5 — per-job escrow row + in-flight action flags.
        val escrow: RepairJobEscrowRepository.EscrowRow? = null,
        val confirmingEscrowRelease: Boolean = false,
        val openingEscrowDispute: Boolean = false,
        val escrowDisputeSheetOpen: Boolean = false,
        val escrowPaymentSheetOpen: Boolean = false,
        /** Open the completion-proof picker sheet (engineer-side, on Mark Done). */
        val proofSheetOpen: Boolean = false,
        /** True while we're enqueuing photos + flipping the status row. */
        val submittingProof: Boolean = false,
        /** v2 — pending revised quote (engineer proposed; hospital hasn't decided). */
        val pendingCostRevision: com.equipseva.app.core.data.repair.CostRevision? = null,
        /** v2 — engineer-side bottom sheet to compose a revised quote. */
        val reviseQuoteSheetOpen: Boolean = false,
        /** v2 — true while propose_cost_revision is in flight. */
        val proposingRevision: Boolean = false,
        /** v2 — hospital-side bottom sheet to approve / reject the pending revision. */
        val revisionDecisionSheetOpen: Boolean = false,
        /** v2 — true while decide_cost_revision is in flight. */
        val decidingRevision: Boolean = false,
        /**
         * Signed-URL projections of [RepairJob.afterPhotos] / [RepairJob.beforePhotos]
         * / [RepairJob.issuePhotos]. The DB stores object paths because the
         * repair-photos bucket is private; AsyncImage can't fetch a path
         * directly, so we mint short-lived signed URLs after the row loads.
         * Same index-alignment as the underlying path list — drop entries
         * we couldn't sign so the rendering site never tries to fetch a
         * blank string.
         */
        val afterPhotoSignedUrls: List<String> = emptyList(),
        val beforePhotoSignedUrls: List<String> = emptyList(),
        val issuePhotoSignedUrls: List<String> = emptyList(),
    ) {
        /** Hide the report CTA when the viewer posted the job. */
        val canReport: Boolean
            get() = job != null && viewerRole != ViewerRole.Hospital
    }

    private val jobId: String =
        checkNotNull(savedState.get<String>(Routes.REPAIR_DETAIL_ARG_ID)) {
            "RepairJobDetailViewModel requires arg ${Routes.REPAIR_DETAIL_ARG_ID}"
        }

    private val _state = MutableStateFlow(RepairJobDetailUiState())
    val state: StateFlow<RepairJobDetailUiState> = _state.asStateFlow()

    private val _messages = Channel<String>(Channel.BUFFERED)
    val messages = _messages.receiveAsFlow()

    private val _effects = Channel<Effect>(Channel.BUFFERED)
    val effects = _effects.receiveAsFlow()

    init {
        load()
        outboxDao.observePendingCountByKind(OutboxKinds.REPAIR_BID)
            .onEach { count -> _state.update { it.copy(queuedBidCount = count) } }
            .launchIn(viewModelScope)
        outboxDao.observePendingCountByKind(OutboxKinds.JOB_STATUS)
            .onEach { count -> _state.update { it.copy(queuedStatusCount = count) } }
            .launchIn(viewModelScope)
        // v2 — pending revised-quote stream. Banner / sheet visibility on
        // both sides keys off this. Realtime sub means an approved /
        // rejected / expired revision automatically collapses the UI.
        costRevisionRepository.observePending(jobId)
            .onEach { rev -> _state.update { it.copy(pendingCostRevision = rev) } }
            .launchIn(viewModelScope)
    }

    fun retry() = load()

    fun onOpenReport() {
        val snap = _state.value
        val job = snap.job ?: return
        if (!snap.canReport) return
        _state.update { it.copy(reportingTargetId = job.id) }
    }

    fun onDismissReport() {
        if (_state.value.submittingReport) return
        _state.update { it.copy(reportingTargetId = null) }
    }

    fun onSubmitReport(reason: ContentReportReason, notes: String?) {
        val id = _state.value.reportingTargetId ?: return
        if (_state.value.submittingReport) return
        _state.update { it.copy(submittingReport = true) }
        viewModelScope.launch {
            reportRepository.submitReport(
                target = ContentReportTarget.RepairJob,
                targetId = id,
                reason = reason,
                notes = notes,
            ).onSuccess {
                _state.update { it.copy(submittingReport = false, reportingTargetId = null) }
                _messages.send("Thanks — our team will review this.")
            }.onFailure { err ->
                _state.update { it.copy(submittingReport = false) }
                _messages.send(err.toUserMessage())
            }
        }
    }

    /**
     * PR-D3: download the compliance audit-trail HTML report. Calls the
     * edge function (which always re-renders so the doc reflects current
     * row state), then emits OpenServiceReport so the screen can hand
     * the URL to the system browser.
     */
    fun generateServiceReport() {
        val job = _state.value.job ?: return
        if (job.status != RepairJobStatus.Completed) return
        if (_state.value.generatingServiceReport) return
        _state.update { it.copy(generatingServiceReport = true) }
        viewModelScope.launch {
            serviceReportRepository.generate(job.id)
                .onSuccess { url ->
                    _state.update { it.copy(generatingServiceReport = false) }
                    _effects.send(Effect.OpenServiceReport(url))
                }
                .onFailure { err ->
                    _state.update { it.copy(generatingServiceReport = false) }
                    _messages.send(err.toUserMessage())
                }
        }
    }

    /** PR-D5: refresh per-job escrow state (no-op on no row). */
    fun refreshEscrow() {
        viewModelScope.launch {
            escrowRepository.fetchByJob(jobId).onSuccess { row ->
                _state.update { it.copy(escrow = row) }
            }
        }
    }

    fun openEscrowPaymentSheet() = _state.update { it.copy(escrowPaymentSheetOpen = true) }
    fun closeEscrowPaymentSheet() = _state.update { it.copy(escrowPaymentSheetOpen = false) }
    fun openEscrowDisputeSheet() = _state.update { it.copy(escrowDisputeSheetOpen = true) }
    fun closeEscrowDisputeSheet() = _state.update { it.copy(escrowDisputeSheetOpen = false) }

    /** Hospital releases escrow early after completion. */
    fun confirmEscrowRelease() {
        if (_state.value.confirmingEscrowRelease) return
        _state.update { it.copy(confirmingEscrowRelease = true) }
        viewModelScope.launch {
            escrowRepository.confirmRelease(jobId)
                .onSuccess {
                    _state.update { it.copy(confirmingEscrowRelease = false) }
                    _messages.send("Released to engineer.")
                    refreshEscrow()
                }
                .onFailure { err ->
                    _state.update { it.copy(confirmingEscrowRelease = false) }
                    _messages.send(err.toUserMessage())
                }
        }
    }

    /** Hospital opens a dispute (within 48h of completion). */
    fun openEscrowDispute(reason: String) {
        if (_state.value.openingEscrowDispute) return
        _state.update { it.copy(openingEscrowDispute = true) }
        viewModelScope.launch {
            escrowRepository.openDispute(jobId, reason)
                .onSuccess {
                    _state.update {
                        it.copy(openingEscrowDispute = false, escrowDisputeSheetOpen = false)
                    }
                    _messages.send("Dispute opened — our team will review.")
                    refreshEscrow()
                }
                .onFailure { err ->
                    _state.update { it.copy(openingEscrowDispute = false) }
                    _messages.send(err.toUserMessage())
                }
        }
    }

    fun openBidComposer() {
        if (_state.value.job == null) return
        _state.update { it.copy(bidComposerOpen = true) }
    }

    fun closeBidComposer() {
        _state.update { it.copy(bidComposerOpen = false) }
    }

    fun submitBid(amountRupees: Double, etaHours: Int?, note: String?) {
        if (_state.value.placingBid) return
        if (!amountRupees.isFinite() || amountRupees !in 1.0..10_000_000.0) {
            viewModelScope.launch { _messages.send("Enter a bid between ₹1 and ₹1 crore") }
            return
        }
        if (etaHours != null && etaHours !in 1..720) {
            viewModelScope.launch { _messages.send("ETA must be 1\u2013720 hours") }
            return
        }
        val hadPending = _state.value.ownBid?.status == RepairBidStatus.Pending
        _state.update { it.copy(placingBid = true) }
        viewModelScope.launch {
            bidRepository.placeBid(
                jobId = jobId,
                amountRupees = amountRupees,
                etaHours = etaHours,
                note = note,
            ).fold(
                onSuccess = { bid ->
                    _state.update {
                        it.copy(
                            ownBid = bid,
                            bidComposerOpen = false,
                            placingBid = false,
                        )
                    }
                    _messages.send(if (hadPending) "Bid updated" else "Bid submitted")
                },
                onFailure = { ex ->
                    queueBidForRetry(amountRupees, etaHours, note)
                    _state.update { it.copy(placingBid = false, bidComposerOpen = false) }
                    _messages.send("Offline — bid will submit when back online")
                },
            )
        }
    }

    private suspend fun queueBidForRetry(
        amountRupees: Double,
        etaHours: Int?,
        note: String?,
    ) {
        val payload = json.encodeToString(
            RepairBidPayload.serializer(),
            RepairBidPayload(
                jobId = jobId,
                amountRupees = amountRupees,
                etaHours = etaHours,
                note = note,
            ),
        )
        outboxEnqueuer.enqueue(OutboxKinds.REPAIR_BID, payload)
    }

    fun openChatWithHospital() {
        val snap = _state.value
        val job = snap.job ?: return
        val hospitalUserId = job.hospitalUserId
        if (hospitalUserId.isNullOrBlank() || snap.openingChat) return
        _state.update { it.copy(openingChat = true) }
        viewModelScope.launch {
            val session = authRepository.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .firstOrNull()
            val selfId = session?.userId
            if (selfId == null) {
                _state.update { it.copy(openingChat = false) }
                _messages.send("Please sign in to start a chat")
                return@launch
            }
            if (selfId == hospitalUserId) {
                _state.update { it.copy(openingChat = false) }
                _messages.send("You're the requester on this job")
                return@launch
            }
            chatRepository.getOrCreateForRepairJob(
                jobId = job.id,
                participantUserIds = listOf(selfId, hospitalUserId),
            ).fold(
                onSuccess = { convo ->
                    _state.update { it.copy(openingChat = false) }
                    _effects.send(Effect.NavigateToChat(convo.id))
                },
                onFailure = { ex ->
                    _state.update { it.copy(openingChat = false) }
                    _messages.send(ex.toUserMessage())
                },
            )
        }
    }

    fun openChatWithEngineer() {
        val snap = _state.value
        val job = snap.job ?: return
        if (snap.openingChat) return
        // Hospital side of the pair: counterparty is the engineer whose bid was accepted.
        // Before acceptance there's no single engineer to chat with, so the UI hides the CTA.
        val engineerUserId = snap.bids
            .firstOrNull { it.status == RepairBidStatus.Accepted }
            ?.engineerUserId
        if (engineerUserId.isNullOrBlank()) {
            _messages.trySend("No engineer assigned yet")
            return
        }
        _state.update { it.copy(openingChat = true) }
        viewModelScope.launch {
            val session = authRepository.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .firstOrNull()
            val selfId = session?.userId
            if (selfId == null) {
                _state.update { it.copy(openingChat = false) }
                _messages.send("Please sign in to start a chat")
                return@launch
            }
            if (selfId == engineerUserId) {
                _state.update { it.copy(openingChat = false) }
                _messages.send("You're the engineer on this job")
                return@launch
            }
            chatRepository.getOrCreateForRepairJob(
                jobId = job.id,
                participantUserIds = listOf(selfId, engineerUserId),
            ).fold(
                onSuccess = { convo ->
                    _state.update { it.copy(openingChat = false) }
                    _effects.send(Effect.NavigateToChat(convo.id))
                },
                onFailure = { ex ->
                    _state.update { it.copy(openingChat = false) }
                    _messages.send(ex.toUserMessage())
                },
            )
        }
    }

    fun withdrawBid() {
        val bid = _state.value.ownBid ?: return
        if (bid.status != RepairBidStatus.Pending) return
        if (_state.value.withdrawingBid) return
        _state.update { it.copy(withdrawingBid = true) }
        viewModelScope.launch {
            bidRepository.withdrawBid(bid.id).fold(
                onSuccess = {
                    bidRepository.fetchOwnBidForJob(jobId).fold(
                        onSuccess = { refreshed ->
                            _state.update { it.copy(ownBid = refreshed, withdrawingBid = false) }
                            _messages.send("Bid withdrawn")
                        },
                        onFailure = { ex ->
                            _state.update { it.copy(withdrawingBid = false) }
                            _messages.send(ex.toUserMessage())
                        },
                    )
                },
                onFailure = { ex ->
                    _state.update { it.copy(withdrawingBid = false) }
                    _messages.send(ex.toUserMessage())
                },
            )
        }
    }

    /**
     * PR-D10 (T2.9): engineer must capture before-photos before
     * checking in. Photos enqueue async via PhotoUploadStash with
     * CONTEXT_REPAIR_JOB_BEFORE → drains into repair_jobs.before_photos.
     * Then the existing geofenced check-in runs. UI gates on
     * photos.isNotEmpty() so server-side enforcement isn't required
     * for v1 — the audit-trail report (PR-D3) flags any check-in
     * with empty before_photos for ops review.
     */
    fun submitCheckinWithProof(photos: List<CompletionProofPhoto>) {
        val snap = _state.value
        val job = snap.job ?: return
        if (snap.viewerRole != ViewerRole.Engineer) return
        if (snap.updatingStatus) return
        if (job.status !in setOf(RepairJobStatus.Assigned, RepairJobStatus.EnRoute)) return
        viewModelScope.launch {
            val session = authRepository.sessionState.firstOrNull() as? AuthSession.SignedIn
            val uid = session?.userId
            if (uid.isNullOrBlank()) {
                _messages.send("Sign in to check in.")
                return@launch
            }
            photos.forEachIndexed { index, photo ->
                runCatching {
                    val storedName = "before-${System.currentTimeMillis()}-$index-${photo.fileName.take(40).replace(Regex("[^A-Za-z0-9._-]"), "_")}"
                    val objectPath = "$uid/${job.id}/$storedName"
                    photoUploadStash.enqueue(
                        bucket = StorageRepository.Buckets.REPAIR_PHOTOS,
                        objectPath = objectPath,
                        bytes = photo.bytes,
                        mimeType = photo.mimeType,
                        contextType = PhotoUploadPayload.CONTEXT_REPAIR_JOB_BEFORE,
                        contextId = job.id,
                        uploaderUserId = uid,
                    )
                }
            }
            checkIn()
        }
    }

    /**
     * PR-D6: GPS-geofenced check-in. Fetches the device fix, calls the
     * SECDEF RPC which enforces a 250m radius vs site_latitude/longitude
     * server-side, and updates UI state from the response. Photos are
     * a separate concern — see [submitCheckinWithProof] which calls
     * this after stashing the before-photos.
     */
    fun checkIn() {
        val job = _state.value.job ?: return
        if (_state.value.updatingStatus) return
        if (job.status !in setOf(RepairJobStatus.Assigned, RepairJobStatus.EnRoute)) return

        _state.update { it.copy(updatingStatus = true) }
        viewModelScope.launch {
            val fix = com.equipseva.app.core.util.fetchCurrentLocation(app)
            if (fix == null) {
                _state.update { it.copy(updatingStatus = false) }
                _messages.send("Turn on location to check in. Geofence is part of the audit trail.")
                return@launch
            }
            jobRepository.engineerCheckInWithGeo(jobId, fix.latitude, fix.longitude)
                .onSuccess { result ->
                    // Refresh row to pick up the new status + started_at.
                    jobRepository.fetchById(jobId).onSuccess { fresh ->
                        if (fresh != null) {
                            _state.update { it.copy(job = fresh, updatingStatus = false) }
                        } else {
                            _state.update { it.copy(updatingStatus = false) }
                        }
                    }.onFailure {
                        _state.update { it.copy(updatingStatus = false) }
                    }
                    val toast = when {
                        result.geofenceSkipped -> "Checked in"
                        result.distanceMeters == null -> "Checked in"
                        else -> "Checked in · ${result.distanceMeters.toInt()}m from site"
                    }
                    _messages.send(toast)
                }
                .onFailure { err ->
                    _state.update { it.copy(updatingStatus = false) }
                    _messages.send(err.toUserMessage())
                }
        }
    }

    fun markDone() = transitionStatus(
        target = RepairJobStatus.Completed,
        allowedFrom = setOf(RepairJobStatus.InProgress, RepairJobStatus.EnRoute),
        requireEngineer = true,
        successMessage = "Marked done",
        setCompletedAt = true,
    )

    /**
     * Engineer taps "Mark done" → we open a sheet to capture proof photos
     * (after_photos). [closeProofSheet] dismisses without committing;
     * [submitCompletionProof] enqueues each photo via [photoUploadStash] and
     * then flips the status row to Completed via the existing [markDone]
     * transition.
     */
    fun openProofSheet() {
        val job = _state.value.job ?: return
        if (_state.value.viewerRole != ViewerRole.Engineer) return
        if (job.status !in setOf(RepairJobStatus.InProgress, RepairJobStatus.EnRoute)) return
        _state.update { it.copy(proofSheetOpen = true) }
    }

    fun closeProofSheet() {
        if (_state.value.submittingProof) return
        _state.update { it.copy(proofSheetOpen = false) }
    }

    // -----------------------------------------------------------------
    // v2 cost-revision flow.
    //   Engineer side: openReviseQuote → proposeCostRevision
    //   Hospital side: openRevisionDecision → decideCostRevision
    // The realtime sub in init() automatically clears
    // pendingCostRevision when the row leaves 'proposed', so the UI
    // banner / sticky CTAs collapse without an explicit refresh.
    // -----------------------------------------------------------------

    fun openReviseQuoteSheet() {
        val snap = _state.value
        if (snap.viewerRole != ViewerRole.Engineer) return
        if (snap.pendingCostRevision != null) return
        val status = snap.job?.status ?: return
        if (status != RepairJobStatus.EnRoute && status != RepairJobStatus.InProgress) return
        _state.update { it.copy(reviseQuoteSheetOpen = true) }
    }

    fun closeReviseQuoteSheet() {
        if (_state.value.proposingRevision) return
        _state.update { it.copy(reviseQuoteSheetOpen = false) }
    }

    fun proposeCostRevision(revisedRupees: Double, reason: String) {
        if (_state.value.proposingRevision) return
        _state.update { it.copy(proposingRevision = true) }
        viewModelScope.launch {
            costRevisionRepository.propose(jobId, revisedRupees, reason)
                .onSuccess { rev ->
                    _state.update {
                        it.copy(
                            proposingRevision = false,
                            reviseQuoteSheetOpen = false,
                            pendingCostRevision = rev,
                        )
                    }
                }
                .onFailure { err ->
                    _state.update {
                        it.copy(
                            proposingRevision = false,
                            errorMessage = err.toUserMessage(),
                        )
                    }
                }
        }
    }

    fun openRevisionDecisionSheet() {
        val snap = _state.value
        if (snap.viewerRole != ViewerRole.Hospital) return
        if (snap.pendingCostRevision == null) return
        _state.update { it.copy(revisionDecisionSheetOpen = true) }
    }

    fun closeRevisionDecisionSheet() {
        if (_state.value.decidingRevision) return
        _state.update { it.copy(revisionDecisionSheetOpen = false) }
    }

    fun decideCostRevision(approve: Boolean) {
        val snap = _state.value
        val rev = snap.pendingCostRevision ?: return
        if (snap.decidingRevision) return
        _state.update { it.copy(decidingRevision = true) }
        viewModelScope.launch {
            costRevisionRepository.decide(rev.id, approve)
                .onSuccess {
                    // Realtime sub will null pendingCostRevision; close
                    // the sheet locally + refresh the job to pick up the
                    // overwritten contractedAmountRupees.
                    _state.update {
                        it.copy(
                            decidingRevision = false,
                            revisionDecisionSheetOpen = false,
                        )
                    }
                    if (approve) load()
                }
                .onFailure { err ->
                    _state.update {
                        it.copy(
                            decidingRevision = false,
                            errorMessage = err.toUserMessage(),
                        )
                    }
                }
        }
    }

    /**
     * Persist each captured photo (offline-safe via PhotoUploadStash with
     * CONTEXT_REPAIR_JOB_AFTER → drains into repair_jobs.after_photos) and
     * then transition the row to Completed. Photos may be empty — we still
     * complete the job (engineer might be offline / forgot a camera) but
     * the UX nudges them to attach proof first.
     */
    fun submitCompletionProof(photos: List<CompletionProofPhoto>) {
        val snap = _state.value
        val job = snap.job ?: return
        if (snap.submittingProof) return
        if (snap.viewerRole != ViewerRole.Engineer) return
        _state.update { it.copy(submittingProof = true) }
        viewModelScope.launch {
            val session = authRepository.sessionState.firstOrNull() as? AuthSession.SignedIn
            val uid = session?.userId
            if (uid.isNullOrBlank()) {
                _state.update { it.copy(submittingProof = false) }
                _messages.send("Sign in to mark this job done")
                return@launch
            }
            // Enqueue each photo. Failures here are non-fatal — we still flip
            // the status; user can re-add photos on the Completed view later.
            photos.forEachIndexed { index, photo ->
                runCatching {
                    val storedName = "after-${System.currentTimeMillis()}-$index-${photo.fileName.take(40).replace(Regex("[^A-Za-z0-9._-]"), "_")}"
                    val objectPath = "$uid/${job.id}/$storedName"
                    photoUploadStash.enqueue(
                        bucket = StorageRepository.Buckets.REPAIR_PHOTOS,
                        objectPath = objectPath,
                        bytes = photo.bytes,
                        mimeType = photo.mimeType,
                        contextType = PhotoUploadPayload.CONTEXT_REPAIR_JOB_AFTER,
                        contextId = job.id,
                        uploaderUserId = uid,
                    )
                }
            }
            _state.update { it.copy(proofSheetOpen = false, submittingProof = false) }
            markDone()
        }
    }

    /**
     * Photo bytes captured by the engineer for completion proof. Held in
     * memory only across the sheet → submit handoff; the stash copies them
     * to disk for offline-safe upload before we move on.
     */
    data class CompletionProofPhoto(
        val fileName: String,
        val mimeType: String,
        val bytes: ByteArray,
    )

    fun cancelJob() = transitionStatus(
        target = RepairJobStatus.Cancelled,
        allowedFrom = setOf(RepairJobStatus.Requested, RepairJobStatus.Assigned),
        requireHospital = true,
        successMessage = "Job cancelled",
    )

    fun submitRating(stars: Int, review: String?) {
        val snap = _state.value
        val job = snap.job ?: return
        if (snap.submittingRating) return
        if (job.status != RepairJobStatus.Completed) return
        val role = when (snap.viewerRole) {
            ViewerRole.Engineer -> RatingRole.EngineerRatesHospital
            ViewerRole.Hospital -> RatingRole.HospitalRatesEngineer
            ViewerRole.Other -> return
        }
        if (stars !in 1..5) return
        _state.update { it.copy(submittingRating = true) }
        viewModelScope.launch {
            jobRepository.submitRating(
                jobId = job.id,
                role = role,
                stars = stars,
                review = review?.trim()?.ifBlank { null },
            ).fold(
                onSuccess = { updated ->
                    _state.update { it.copy(submittingRating = false, job = updated) }
                    _messages.send("Thanks — rating submitted")
                },
                onFailure = { ex ->
                    _state.update { it.copy(submittingRating = false) }
                    _messages.send(ex.toUserMessage())
                },
            )
        }
    }

    private fun transitionStatus(
        target: RepairJobStatus,
        allowedFrom: Set<RepairJobStatus>,
        successMessage: String,
        requireEngineer: Boolean = false,
        requireHospital: Boolean = false,
        setStartedAt: Boolean = false,
        setCompletedAt: Boolean = false,
    ) {
        val snap = _state.value
        val job = snap.job ?: return
        if (snap.updatingStatus) return
        if (requireEngineer && snap.viewerRole != ViewerRole.Engineer) return
        if (requireHospital && snap.viewerRole != ViewerRole.Hospital) return
        if (job.status !in allowedFrom) return
        _state.update { it.copy(updatingStatus = true) }
        viewModelScope.launch {
            val now = Instant.now()
            jobRepository.updateStatus(
                jobId = job.id,
                newStatus = target,
                startedAt = if (setStartedAt) now else null,
                completedAt = if (setCompletedAt) now else null,
            ).fold(
                onSuccess = { updated ->
                    _state.update { it.copy(updatingStatus = false, job = updated) }
                    _messages.send(successMessage)
                },
                onFailure = { ex ->
                    queueStatusForRetry(
                        jobId = job.id,
                        target = target,
                        startedAtEpochMs = if (setStartedAt) now.toEpochMilli() else null,
                        completedAtEpochMs = if (setCompletedAt) now.toEpochMilli() else null,
                    )
                    _state.update {
                        it.copy(
                            updatingStatus = false,
                            job = it.job?.copy(status = target),
                        )
                    }
                    _messages.send("Offline — status change will apply when back online")
                },
            )
        }
    }

    private suspend fun queueStatusForRetry(
        jobId: String,
        target: RepairJobStatus,
        startedAtEpochMs: Long?,
        completedAtEpochMs: Long?,
    ) {
        val payload = json.encodeToString(
            JobStatusPayload.serializer(),
            JobStatusPayload(
                jobId = jobId,
                newStatus = target.name,
                startedAtEpochMs = startedAtEpochMs,
                completedAtEpochMs = completedAtEpochMs,
            ),
        )
        outboxEnqueuer.enqueue(OutboxKinds.JOB_STATUS, payload)
    }

    fun acceptBid(bidId: String) {
        val snap = _state.value
        if (snap.viewerRole != ViewerRole.Hospital) return
        if (snap.acceptingBidId != null) return
        if (snap.job?.status != RepairJobStatus.Requested) return
        _state.update { it.copy(acceptingBidId = bidId) }
        viewModelScope.launch {
            bidRepository.acceptBid(bidId).fold(
                onSuccess = {
                    // Refresh job + bids so the stepper and bid list reflect the
                    // accepted/rejected statuses in one shot.
                    val refreshedJob = jobRepository.fetchById(jobId).getOrNull()
                    val refreshedBids = bidRepository.fetchBidsForJob(jobId).getOrNull().orEmpty()
                    val known = _state.value.engineerNames
                    val missing = refreshedBids
                        .map { it.engineerUserId }
                        .filter { it !in known }
                    val refreshedNames = if (missing.isNotEmpty()) {
                        known + profileRepository.fetchDisplayNames(missing).getOrNull().orEmpty()
                    } else {
                        known
                    }
                    _state.update {
                        it.copy(
                            job = refreshedJob ?: it.job,
                            bids = refreshedBids,
                            acceptingBidId = null,
                            engineerNames = refreshedNames,
                        )
                    }
                    _messages.send("Bid accepted — engineer notified")
                },
                onFailure = { ex ->
                    _state.update { it.copy(acceptingBidId = null) }
                    _messages.send(ex.toUserMessage())
                },
            )
        }
    }

    private fun load() {
        _state.update { it.copy(loading = true, errorMessage = null, notFound = false) }
        viewModelScope.launch {
            val selfId = (authRepository.sessionState.firstOrNull() as? AuthSession.SignedIn)?.userId
            val selfEngineerRowId = selfId
                ?.let { engineerRepository.fetchByUserId(it).getOrNull()?.id }
            // Falls back to in-app active role when the engineers row hasn't
            // been created yet — a brand-new engineer signed up via the role
            // tile (PR #225) may have role='engineer' in profiles but no
            // engineers row until they finish KYC. UserPrefs.activeRole is
            // also the source of truth for which Hub the user is currently in
            // (Hub can switch role without touching the auth profile). We
            // still want Place bid visible for them; server RLS rejects with
            // a clear error if they tap Submit without an engineers row.
            val selfProfileRole = selfId
                ?.let { profileRepository.fetchById(it).getOrNull()?.role?.storageKey }
            val selfActiveRole = userPrefs.activeRole.firstOrNull()
            val jobResult = jobRepository.fetchById(jobId)
            jobResult.fold(
                onSuccess = { job ->
                    val role = resolveViewerRole(job, selfId, selfEngineerRowId, selfProfileRole, selfActiveRole)
                    // Hospital viewer wants every bid to pick a winner; engineer
                    // viewer only needs their own row for the "Your bid" card.
                    val bids = when (role) {
                        ViewerRole.Hospital -> bidRepository.fetchBidsForJob(jobId)
                            .getOrNull().orEmpty()
                        ViewerRole.Engineer,
                        ViewerRole.Other -> emptyList()
                    }
                    val ownBid = when (role) {
                        ViewerRole.Engineer -> bidRepository.fetchOwnBidForJob(jobId).getOrNull()
                        ViewerRole.Hospital -> bids.firstOrNull { it.engineerUserId == selfId }
                        ViewerRole.Other -> bidRepository.fetchOwnBidForJob(jobId).getOrNull()
                    }
                    val engineerNames = if (role == ViewerRole.Hospital && bids.isNotEmpty()) {
                        profileRepository.fetchDisplayNames(
                            bids.map { it.engineerUserId },
                        ).getOrNull().orEmpty()
                    } else {
                        emptyMap()
                    }
                    val hospitalProfile = if (role != ViewerRole.Hospital) {
                        job?.hospitalUserId?.let { hospitalId ->
                            profileRepository.fetchById(hospitalId).getOrNull()
                        }
                    } else {
                        null
                    }
                    _state.update {
                        it.copy(
                            loading = false,
                            job = job,
                            notFound = job == null,
                            ownBid = ownBid,
                            bids = bids,
                            viewerRole = role,
                            engineerNames = engineerNames,
                            hospitalName = hospitalProfile?.displayName,
                            hospitalLocation = hospitalProfile?.locationLine,
                        )
                    }
                    job?.let { resolvePhotoSignedUrls(it) }
                    if (job != null) refreshEscrow()
                },
                onFailure = { ex ->
                    _state.update {
                        it.copy(
                            loading = false,
                            errorMessage = ex.toUserMessage(),
                        )
                    }
                },
            )
        }
    }

    /**
     * Mints short-lived signed URLs for every path on the loaded job's
     * after_photos / before_photos / issue_photos arrays so the rendering
     * site can pass them straight into AsyncImage. The repair-photos bucket
     * is private, and the DB stores raw object paths — without this step
     * a path string lands in AsyncImage and Coil silently fails to fetch.
     *
     * Failures per-path are dropped (the gallery just shows fewer thumbs)
     * rather than poisoning the whole load. Storage policy gates SELECT to
     * job participants so cross-user views still work after the new RLS
     * policy in 20260428200000.
     */
    private fun resolvePhotoSignedUrls(job: RepairJob) {
        viewModelScope.launch {
            suspend fun signAll(paths: List<String>): List<String> = paths.mapNotNull { path ->
                runCatching {
                    storageRepository.signedUrl(StorageRepository.Buckets.REPAIR_PHOTOS, path)
                }.getOrNull()
            }
            val after = signAll(job.afterPhotos)
            val before = signAll(job.beforePhotos)
            val issue = signAll(job.issuePhotos)
            _state.update {
                it.copy(
                    afterPhotoSignedUrls = after,
                    beforePhotoSignedUrls = before,
                    issuePhotoSignedUrls = issue,
                )
            }
        }
    }

    private fun resolveViewerRole(
        job: RepairJob?,
        selfId: String?,
        selfEngineerRowId: String?,
        selfProfileRole: String?,
        selfActiveRole: String?,
    ): ViewerRole {
        if (job == null || selfId.isNullOrBlank()) return ViewerRole.Other
        return when {
            selfId == job.hospitalUserId -> ViewerRole.Hospital
            // Three signals counted as "user is an engineer", in order of
            // server-side trust:
            //   1. engineers row exists (fully onboarded, KYC complete)
            //   2. profiles.role == 'engineer' (signed up via role tile #225)
            //   3. UserPrefs.activeRole == 'engineer' (currently in Engineer
            //      Hub on this device — Hub can switch persona without
            //      writing to the auth profile)
            // 1 lets them actually bid server-side; 2 and 3 let them at
            // least see the Place bid CTA so they discover the next-step
            // prompt. RLS surfaces a clear error if they tap Submit without
            // an engineers row.
            !selfEngineerRowId.isNullOrBlank() -> ViewerRole.Engineer
            selfProfileRole == "engineer" -> ViewerRole.Engineer
            selfActiveRole == "engineer" -> ViewerRole.Engineer
            else -> ViewerRole.Other
        }
    }

    private fun buildDummyJob(id: String): RepairJob {
        // Pre-canned dummies for the hospital Bookings list. Switching on the
        // suffix here mirrors what HospitalActiveJobsViewModel seeds when the
        // backend returns no rows so taps land on the matching job, not a
        // generic Patient-monitor stand-in.
        return when (id) {
            "dummy-h-open-1" -> dummyJob(
                id, "RJ-2026-0420",
                "Patient monitor — intermittent screen flicker",
                "ICU bay 3 monitor flickers intermittently for the past 2 days. Sometimes goes blank for ~5s. No alarm sounded but readings stop updating.",
                RepairEquipmentCategory.PatientMonitoring, "Philips", "IntelliVue MX450",
                "ICU bay 3, Sri Sai Multi-Specialty, Nalgonda",
                RepairJobStatus.Requested, RepairJobUrgency.SameDay, 3500.0,
            )
            "dummy-h-prog-1" -> dummyJob(
                id, "RJ-2026-0410",
                "Anaesthesia machine — gas leak",
                "Suspected leak around vapouriser seat. OT scheduled tomorrow.",
                RepairEquipmentCategory.LifeSupport, "Drager", "Fabius Plus",
                "OT 2, Sri Sai Multi-Specialty, Nalgonda",
                RepairJobStatus.InProgress, RepairJobUrgency.Emergency, 4200.0,
            )
            "dummy-h-prog-2" -> dummyJob(
                id, "RJ-2026-0411",
                "ECG cable replacement",
                "3-lead cable damaged. Replacement bringing tomorrow.",
                RepairEquipmentCategory.PatientMonitoring, "Philips", "Efficia CM150",
                "Ward 4, Yashoda Hospital, Nalgonda",
                RepairJobStatus.Assigned, RepairJobUrgency.Scheduled, 800.0,
            )
            "dummy-h-done-1" -> dummyJob(
                id, "RJ-2026-0398",
                "Ultrasound probe calibration",
                "Convex probe calibration completed. Image quality verified.",
                RepairEquipmentCategory.ImagingRadiology, "GE", "Logiq P9",
                "Radiology, City Care, Khammam",
                RepairJobStatus.Completed, RepairJobUrgency.Scheduled, 4500.0,
            )
            "dummy-h-done-2" -> dummyJob(
                id, "RJ-2026-0395",
                "Centrifuge service",
                "Belt replaced, vibration corrected. Ran calibration cycle.",
                RepairEquipmentCategory.Laboratory, "Eppendorf", "5810R",
                "Lab, Care Lab, Hyderabad",
                RepairJobStatus.Completed, RepairJobUrgency.Scheduled, 2200.0,
            )
            // Mirror ActiveWorkViewModel's seeded engineer-side dummies so a
            // tap on one of those rows opens the matching detail instead of
            // the generic Patient-monitor stand-in.
            "dummy-job-active-1" -> dummyJob(
                id, "RJ-2026-0410",
                "Anaesthesia machine — gas leak",
                "Suspected leak around vapouriser seat. OT scheduled tomorrow.",
                RepairEquipmentCategory.LifeSupport, "Drager", "Fabius Plus",
                "OT 2, Sri Sai Multi-Specialty, Nalgonda",
                RepairJobStatus.InProgress, RepairJobUrgency.Emergency, 4200.0,
            )
            "dummy-job-active-2" -> dummyJob(
                id, "RJ-2026-0411",
                "ECG cable replacement",
                "3-lead cable damaged. Replacement onsite.",
                RepairEquipmentCategory.PatientMonitoring, "Philips", "Efficia CM150",
                "Ward 4, Yashoda Hospital, Nalgonda",
                RepairJobStatus.EnRoute, RepairJobUrgency.Scheduled, 800.0,
            )
            "dummy-job-done-1" -> dummyJob(
                id, "RJ-2026-0398",
                "Ultrasound probe calibration",
                "Convex probe calibration completed. Image quality verified.",
                RepairEquipmentCategory.ImagingRadiology, "GE", "Logiq P9",
                "Radiology, City Care, Khammam",
                RepairJobStatus.Completed, RepairJobUrgency.Scheduled, 4500.0,
            )
            "dummy-job-done-2" -> dummyJob(
                id, "RJ-2026-0395",
                "Centrifuge service",
                "Belt replaced, vibration corrected.",
                RepairEquipmentCategory.Laboratory, "Eppendorf", "5810R",
                "Lab, Care Lab, Hyderabad",
                RepairJobStatus.Completed, RepairJobUrgency.Scheduled, 2200.0,
            )
            else -> dummyJob(
                id, "RJ-2026-0420",
                "Patient monitor — intermittent screen flicker",
                "Patient monitor in ICU bay 3 shows intermittent screen flicker for the past 2 days. Sometimes goes blank for ~5s. No alarm sounded but readings stop updating during the blackout.",
                RepairEquipmentCategory.PatientMonitoring, "Philips", "IntelliVue MX450",
                "ICU bay 3, Sri Sai Multi-Specialty, Nalgonda",
                RepairJobStatus.Requested, RepairJobUrgency.SameDay, 3500.0,
            )
        }
    }

    private fun dummyJob(
        id: String,
        no: String,
        title: String,
        issue: String,
        cat: RepairEquipmentCategory,
        brand: String,
        model: String,
        site: String,
        status: RepairJobStatus,
        urgency: RepairJobUrgency,
        cost: Double,
    ): RepairJob = RepairJob(
        id = id,
        jobNumber = no,
        title = title,
        issueDescription = issue,
        equipmentCategory = cat,
        equipmentBrand = brand,
        equipmentModel = model,
        status = status,
        urgency = urgency,
        estimatedCostRupees = cost,
        scheduledDate = java.time.LocalDate.now().plusDays(1).toString(),
        scheduledTimeSlot = "morning",
        siteLocation = site,
        siteLatitude = null,
        siteLongitude = null,
        isAssignedToEngineer = status != RepairJobStatus.Requested,
        engineerId = if (status != RepairJobStatus.Requested) "dummy-eng-1" else null,
        hospitalUserId = "dummy-hospital",
        startedAtInstant = if (status == RepairJobStatus.InProgress) java.time.Instant.now().minusSeconds(7200) else null,
        completedAtInstant = if (status == RepairJobStatus.Completed) java.time.Instant.now().minusSeconds(86400 * 3) else null,
        hospitalRating = if (status == RepairJobStatus.Completed) 5 else null,
        hospitalReview = null,
        engineerRating = null,
        engineerReview = null,
        createdAtInstant = java.time.Instant.now().minusSeconds(86400),
        updatedAtInstant = java.time.Instant.now(),
    )
}
