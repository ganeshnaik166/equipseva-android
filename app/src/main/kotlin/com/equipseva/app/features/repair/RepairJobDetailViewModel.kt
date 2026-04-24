package com.equipseva.app.features.repair

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.chat.ChatRepository
import com.equipseva.app.core.data.engineers.EngineerRepository
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.data.repair.JobStatusPayload
import com.equipseva.app.core.data.repair.RatingRole
import com.equipseva.app.core.data.repair.RepairBid
import com.equipseva.app.core.data.repair.RepairBidPayload
import com.equipseva.app.core.data.repair.RepairBidRepository
import com.equipseva.app.core.data.repair.RepairBidStatus
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobRepository
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.sync.OutboxEnqueuer
import com.equipseva.app.core.sync.OutboxKinds
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
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import javax.inject.Inject

@HiltViewModel
class RepairJobDetailViewModel @Inject constructor(
    savedState: SavedStateHandle,
    private val jobRepository: RepairJobRepository,
    private val bidRepository: RepairBidRepository,
    private val chatRepository: ChatRepository,
    private val authRepository: AuthRepository,
    private val engineerRepository: EngineerRepository,
    private val profileRepository: ProfileRepository,
    private val outboxEnqueuer: OutboxEnqueuer,
    private val json: Json,
) : ViewModel() {

    sealed interface Effect {
        data class NavigateToChat(val conversationId: String) : Effect
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
    )

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
    }

    fun retry() = load()

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

    fun checkIn() = transitionStatus(
        target = RepairJobStatus.InProgress,
        allowedFrom = setOf(RepairJobStatus.Assigned, RepairJobStatus.EnRoute),
        requireEngineer = true,
        successMessage = "Checked in",
        setStartedAt = true,
    )

    fun markDone() = transitionStatus(
        target = RepairJobStatus.Completed,
        allowedFrom = setOf(RepairJobStatus.InProgress, RepairJobStatus.EnRoute),
        requireEngineer = true,
        successMessage = "Marked done",
        setCompletedAt = true,
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
            val jobResult = jobRepository.fetchById(jobId)
            jobResult.fold(
                onSuccess = { job ->
                    val role = resolveViewerRole(job, selfId, selfEngineerRowId)
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

    private fun resolveViewerRole(
        job: RepairJob?,
        selfId: String?,
        selfEngineerRowId: String?,
    ): ViewerRole {
        if (job == null || selfId.isNullOrBlank()) return ViewerRole.Other
        return when {
            selfId == job.hospitalUserId -> ViewerRole.Hospital
            // `repair_jobs.engineer_id` FKs to `engineers.id`, not auth.uid —
            // compare against the engineer row id we resolved for this user.
            !selfEngineerRowId.isNullOrBlank() && selfEngineerRowId == job.engineerId ->
                ViewerRole.Engineer
            else -> ViewerRole.Other
        }
    }
}
