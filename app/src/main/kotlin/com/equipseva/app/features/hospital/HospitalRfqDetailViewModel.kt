package com.equipseva.app.features.hospital

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.chat.ChatRepository
import com.equipseva.app.core.data.moderation.ContentReportReason
import com.equipseva.app.core.data.moderation.ContentReportRepository
import com.equipseva.app.core.data.moderation.ContentReportTarget
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.data.rfq.Rfq
import com.equipseva.app.core.data.rfq.RfqBid
import com.equipseva.app.core.data.rfq.RfqRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.navigation.Routes
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.async
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class HospitalRfqDetailViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val rfqRepository: RfqRepository,
    private val chatRepository: ChatRepository,
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
    private val reportRepository: ContentReportRepository,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val rfq: Rfq? = null,
        val bids: List<RfqBid> = emptyList(),
        val acceptingBidId: String? = null,
        val openingChatForBidId: String? = null,
        val errorMessage: String? = null,
        /** Org id of the signed-in user — used to hide report on own RFQs. */
        val selfOrgId: String? = null,
        val reportingTargetId: String? = null,
        val submittingReport: Boolean = false,
    ) {
        /** Hide the report CTA when the viewer's org is the requesting org. */
        val canReport: Boolean
            get() {
                val rfq = rfq ?: return false
                return selfOrgId == null || selfOrgId != rfq.requesterOrgId
            }
    }

    sealed interface Effect {
        data class ShowMessage(val text: String) : Effect
        data class NavigateToChat(val conversationId: String) : Effect
    }

    private val rfqId: String = checkNotNull(savedStateHandle[Routes.HOSPITAL_RFQ_DETAIL_ARG_ID])

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private val _effects = Channel<Effect>(Channel.BUFFERED)
    val effects = _effects.receiveAsFlow()

    init {
        load(initial = true)
        viewModelScope.launch {
            val session = authRepository.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .firstOrNull()
            val orgId = session?.userId
                ?.let { profileRepository.fetchById(it).getOrNull()?.organizationId }
            _state.update { it.copy(selfOrgId = orgId) }
        }
    }

    fun onRefresh() = load(initial = false)

    fun onOpenReport() {
        val rfq = _state.value.rfq ?: return
        if (!_state.value.canReport) return
        _state.update { it.copy(reportingTargetId = rfq.id) }
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
                target = ContentReportTarget.Rfq,
                targetId = id,
                reason = reason,
                notes = notes,
            ).onSuccess {
                _state.update { it.copy(submittingReport = false, reportingTargetId = null) }
                emit(Effect.ShowMessage("Thanks — our team will review this."))
            }.onFailure { err ->
                _state.update { it.copy(submittingReport = false) }
                emit(Effect.ShowMessage(err.toUserMessage()))
            }
        }
    }

    fun onMessageSupplier(bid: RfqBid) {
        if (_state.value.openingChatForBidId != null) return
        _state.update { it.copy(openingChatForBidId = bid.id) }
        viewModelScope.launch {
            val session = authRepository.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .firstOrNull()
            val selfId = session?.userId
            if (selfId == null) {
                _state.update { it.copy(openingChatForBidId = null) }
                emit(Effect.ShowMessage("Sign in to start a chat"))
                return@launch
            }
            if (selfId == bid.manufacturerId) {
                _state.update { it.copy(openingChatForBidId = null) }
                emit(Effect.ShowMessage("You are the supplier on this bid"))
                return@launch
            }
            chatRepository.getOrCreateForRfqBid(
                bidId = bid.id,
                participantUserIds = listOf(selfId, bid.manufacturerId),
            ).onSuccess { convo ->
                _state.update { it.copy(openingChatForBidId = null) }
                emit(Effect.NavigateToChat(convo.id))
            }.onFailure { error ->
                _state.update { it.copy(openingChatForBidId = null) }
                emit(Effect.ShowMessage(error.toUserMessage()))
            }
        }
    }

    fun onAcceptBid(bid: RfqBid) {
        if (_state.value.acceptingBidId != null) return
        _state.update { it.copy(acceptingBidId = bid.id) }
        viewModelScope.launch {
            rfqRepository.acceptBid(bid.id, bid.rfqId)
                .onSuccess {
                    // Refresh the list so the accepted/rejected chips flip before we
                    // (best-effort) drop the buyer into the chat with the supplier.
                    load(initial = false)
                    val navigated = openChatAfterAccept(bid)
                    _state.update { it.copy(acceptingBidId = null) }
                    if (!navigated) {
                        emit(Effect.ShowMessage("Bid accepted"))
                    }
                }
                .onFailure { error ->
                    _state.update { it.copy(acceptingBidId = null) }
                    emit(Effect.ShowMessage(error.toUserMessage()))
                }
        }
    }

    /**
     * Mirrors the repair-bid accept flow: after the bid flips to accepted we
     * land the buyer in a 1:1 conversation with the supplier on that bid.
     *
     * Returns `true` if a NavigateToChat effect was emitted. Any failure here
     * is non-fatal — the accept has already committed — so we surface a
     * toast and fall back to the standard "Bid accepted" snackbar.
     */
    private suspend fun openChatAfterAccept(bid: RfqBid): Boolean {
        val session = authRepository.sessionState
            .filterIsInstance<AuthSession.SignedIn>()
            .firstOrNull()
        val selfId = session?.userId
        if (selfId.isNullOrBlank()) {
            emit(Effect.ShowMessage("Bid accepted — sign in again to message the supplier"))
            return false
        }
        val supplierUserId = bid.manufacturerId
        if (supplierUserId.isBlank() || supplierUserId == selfId) {
            // Degenerate case — mirrors onMessageSupplier guards.
            emit(Effect.ShowMessage("Bid accepted"))
            return false
        }
        return chatRepository.getOrCreateForRfqBid(
            bidId = bid.id,
            participantUserIds = listOf(selfId, supplierUserId),
        ).fold(
            onSuccess = { convo ->
                emit(Effect.NavigateToChat(convo.id))
                true
            },
            onFailure = { error ->
                emit(Effect.ShowMessage("Bid accepted — ${error.toUserMessage()}"))
                false
            },
        )
    }

    private fun emit(effect: Effect) {
        viewModelScope.launch { _effects.send(effect) }
    }

    private fun load(initial: Boolean) {
        _state.update { it.copy(loading = initial, refreshing = !initial, errorMessage = null) }
        viewModelScope.launch {
            runCatching {
                coroutineScope {
                    val rfqDeferred = async { rfqRepository.fetchRfqById(rfqId).getOrThrow() }
                    val bidsDeferred = async { rfqRepository.fetchBidsForRfq(rfqId).getOrThrow() }
                    rfqDeferred.await() to bidsDeferred.await()
                }
            }.onSuccess { (rfq, bids) ->
                _state.update {
                    it.copy(
                        loading = false,
                        refreshing = false,
                        rfq = rfq,
                        bids = bids,
                        errorMessage = null,
                    )
                }
            }.onFailure { error ->
                _state.update {
                    it.copy(
                        loading = false,
                        refreshing = false,
                        errorMessage = error.toUserMessage(),
                    )
                }
            }
        }
    }
}
