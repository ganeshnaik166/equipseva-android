package com.equipseva.app.features.repair

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.chat.ChatRepository
import com.equipseva.app.core.data.repair.RatingRole
import com.equipseva.app.core.data.repair.RepairBid
import com.equipseva.app.core.data.repair.RepairBidRepository
import com.equipseva.app.core.data.repair.RepairBidStatus
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobRepository
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.core.network.toUserMessage
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
import javax.inject.Inject

@HiltViewModel
class RepairJobDetailViewModel @Inject constructor(
    savedState: SavedStateHandle,
    private val jobRepository: RepairJobRepository,
    private val bidRepository: RepairBidRepository,
    private val chatRepository: ChatRepository,
    private val authRepository: AuthRepository,
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
                    _state.update { it.copy(placingBid = false) }
                    _messages.send(ex.toUserMessage())
                },
            )
        }
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
        requireEngineer: Boolean,
        successMessage: String,
        setStartedAt: Boolean = false,
        setCompletedAt: Boolean = false,
    ) {
        val snap = _state.value
        val job = snap.job ?: return
        if (snap.updatingStatus) return
        if (requireEngineer && snap.viewerRole != ViewerRole.Engineer) return
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
                    _state.update { it.copy(updatingStatus = false) }
                    _messages.send(ex.toUserMessage())
                },
            )
        }
    }

    private fun load() {
        _state.update { it.copy(loading = true, errorMessage = null, notFound = false) }
        viewModelScope.launch {
            val selfId = (authRepository.sessionState.firstOrNull() as? AuthSession.SignedIn)?.userId
            val jobResult = jobRepository.fetchById(jobId)
            val bidResult = bidRepository.fetchOwnBidForJob(jobId)
            jobResult.fold(
                onSuccess = { job ->
                    val role = resolveViewerRole(job, selfId)
                    _state.update {
                        it.copy(
                            loading = false,
                            job = job,
                            notFound = job == null,
                            ownBid = bidResult.getOrNull(),
                            viewerRole = role,
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

    private fun resolveViewerRole(job: RepairJob?, selfId: String?): ViewerRole {
        if (job == null || selfId.isNullOrBlank()) return ViewerRole.Other
        return when (selfId) {
            job.hospitalUserId -> ViewerRole.Hospital
            job.engineerId -> ViewerRole.Engineer
            else -> ViewerRole.Other
        }
    }
}
