package com.equipseva.app.features.hospital

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.chat.ChatRepository
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
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val rfq: Rfq? = null,
        val bids: List<RfqBid> = emptyList(),
        val acceptingBidId: String? = null,
        val openingChatForBidId: String? = null,
        val errorMessage: String? = null,
    )

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
    }

    fun onRefresh() = load(initial = false)

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
                    _state.update { it.copy(acceptingBidId = null) }
                    emit(Effect.ShowMessage("Bid accepted"))
                    load(initial = false)
                }
                .onFailure { error ->
                    _state.update { it.copy(acceptingBidId = null) }
                    emit(Effect.ShowMessage(error.toUserMessage()))
                }
        }
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
                    UiState(loading = false, refreshing = false, rfq = rfq, bids = bids)
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
