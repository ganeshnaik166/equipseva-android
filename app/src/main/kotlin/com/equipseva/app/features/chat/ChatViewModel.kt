package com.equipseva.app.features.chat

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.chat.ChatMessage
import com.equipseva.app.core.data.chat.ChatMessagePayload
import com.equipseva.app.core.data.chat.ChatRepository
import com.equipseva.app.core.data.dao.OutboxDao
import com.equipseva.app.core.data.moderation.ContentReportReason
import com.equipseva.app.core.data.moderation.ContentReportRepository
import com.equipseva.app.core.data.moderation.ContentReportTarget
import com.equipseva.app.core.data.profile.Profile
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.sync.OutboxEnqueuer
import com.equipseva.app.core.sync.OutboxKinds
import com.equipseva.app.navigation.Routes
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import javax.inject.Inject

@HiltViewModel
class ChatViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val authRepository: AuthRepository,
    private val chatRepository: ChatRepository,
    private val profileRepository: ProfileRepository,
    private val outboxEnqueuer: OutboxEnqueuer,
    private val outboxDao: OutboxDao,
    private val reportRepository: ContentReportRepository,
    private val json: Json,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val selfUserId: String? = null,
        val counterpart: Profile? = null,
        val messages: List<ChatMessage> = emptyList(),
        val draft: String = "",
        val sending: Boolean = false,
        val queuedCount: Int = 0,
        val reportingMessageId: String? = null,
        val submittingReport: Boolean = false,
        val errorMessage: String? = null,
    ) {
        val title: String
            get() = counterpart?.displayName ?: "Chat"
        val canSend: Boolean
            get() = draft.trim().isNotEmpty() && !sending && selfUserId != null
    }

    sealed interface Effect {
        data class ShowMessage(val text: String) : Effect
    }

    private val conversationId: String = requireNotNull(savedStateHandle[Routes.CHAT_DETAIL_ARG_ID]) {
        "Missing conversationId nav arg"
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private val _effects = Channel<Effect>(Channel.BUFFERED)
    val effects = _effects.receiveAsFlow()

    init {
        viewModelScope.launch {
            val session = authRepository.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .first()
            _state.update { it.copy(selfUserId = session.userId) }
            loadConversationMeta(session.userId)
            observeMessages(session.userId)
        }
        outboxDao.observePendingCountByKind(OutboxKinds.CHAT_MESSAGE)
            .onEach { count -> _state.update { it.copy(queuedCount = count) } }
            .launchIn(viewModelScope)
    }

    fun onDraftChange(value: String) {
        _state.update { it.copy(draft = value) }
    }

    fun onSend() {
        val snap = _state.value
        val text = snap.draft.trim()
        val self = snap.selfUserId
        if (text.isEmpty() || self == null || snap.sending) return
        _state.update { it.copy(sending = true, draft = "") }
        viewModelScope.launch {
            chatRepository.sendMessage(conversationId, self, text)
                .onFailure { error ->
                    queueForRetry(self, text)
                    _state.update { it.copy(sending = false) }
                    _effects.send(Effect.ShowMessage("Offline — message will send when back online"))
                }
                .onSuccess {
                    _state.update { it.copy(sending = false) }
                }
        }
    }

    fun onOpenReport(messageId: String) {
        _state.update { it.copy(reportingMessageId = messageId) }
    }

    fun onDismissReport() {
        if (_state.value.submittingReport) return
        _state.update { it.copy(reportingMessageId = null) }
    }

    fun onSubmitReport(reason: ContentReportReason, notes: String?) {
        val id = _state.value.reportingMessageId ?: return
        if (_state.value.submittingReport) return
        _state.update { it.copy(submittingReport = true) }
        viewModelScope.launch {
            reportRepository.submitReport(
                target = ContentReportTarget.ChatMessage,
                targetId = id,
                reason = reason,
                notes = notes,
            ).onSuccess {
                _state.update { it.copy(submittingReport = false, reportingMessageId = null) }
                _effects.send(Effect.ShowMessage("Thanks — our team will review this."))
            }.onFailure { err ->
                _state.update { it.copy(submittingReport = false) }
                _effects.send(Effect.ShowMessage(err.toUserMessage()))
            }
        }
    }

    private suspend fun queueForRetry(selfUserId: String, text: String) {
        val payload = json.encodeToString(
            ChatMessagePayload.serializer(),
            ChatMessagePayload(
                conversationId = conversationId,
                senderUserId = selfUserId,
                body = text,
            ),
        )
        outboxEnqueuer.enqueue(OutboxKinds.CHAT_MESSAGE, payload)
    }

    private suspend fun loadConversationMeta(selfUserId: String) {
        chatRepository.fetchById(conversationId)
            .onSuccess { convo ->
                val otherId = convo?.counterpartId(selfUserId)
                if (otherId != null) {
                    profileRepository.fetchById(otherId)
                        .onSuccess { other -> _state.update { it.copy(counterpart = other) } }
                }
                // Fire-and-forget read receipt.
                viewModelScope.launch { chatRepository.markConversationRead(conversationId, selfUserId) }
            }
            .onFailure { error ->
                _state.update { it.copy(errorMessage = error.toUserMessage()) }
            }
    }

    private fun observeMessages(selfUserId: String) {
        chatRepository.observeMessages(conversationId)
            .onEach { list ->
                _state.update { it.copy(loading = false, messages = list, errorMessage = null) }
                viewModelScope.launch { chatRepository.markConversationRead(conversationId, selfUserId) }
            }
            .catch { error ->
                _state.update { it.copy(loading = false, errorMessage = error.toUserMessage()) }
            }
            .launchIn(viewModelScope)
    }
}
