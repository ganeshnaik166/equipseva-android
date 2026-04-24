package com.equipseva.app.features.chat

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.chat.ChatConversation
import com.equipseva.app.core.data.chat.ChatRepository
import com.equipseva.app.core.data.dao.OutboxDao
import com.equipseva.app.core.data.moderation.UserBlockRepository
import com.equipseva.app.core.data.profile.Profile
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.sync.OutboxKinds
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class ConversationsViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val chatRepository: ChatRepository,
    private val profileRepository: ProfileRepository,
    private val outboxDao: OutboxDao,
    private val userBlockRepository: UserBlockRepository,
) : ViewModel() {

    data class Row(
        val conversation: ChatConversation,
        val counterpart: Profile?,
    ) {
        val title: String get() = counterpart?.displayName ?: "Conversation"
        val preview: String get() = conversation.lastMessage?.takeIf { it.isNotBlank() } ?: "No messages yet"
    }

    data class UiState(
        val loading: Boolean = true,
        val rows: List<Row> = emptyList(),
        val queuedCount: Int = 0,
        val errorMessage: String? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    // Cache counterpart profiles so we don't re-fetch on every realtime tick.
    private val profileCache = mutableMapOf<String, Profile?>()

    init {
        viewModelScope.launch {
            val session = authRepository.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .first()
            combine(
                chatRepository.observeConversations(session.userId),
                userBlockRepository.observeBlockedUserIds(),
            ) { list, blocked ->
                list.filter { convo ->
                    val other = convo.counterpartId(session.userId)
                    other == null || other !in blocked
                }
            }
                .onEach { list -> buildRows(session.userId, list) }
                .catch { error ->
                    _state.update { it.copy(loading = false, errorMessage = error.toUserMessage()) }
                }
                .launchIn(viewModelScope)
        }
        outboxDao.observePendingCountByKind(OutboxKinds.CHAT_MESSAGE)
            .onEach { count -> _state.update { it.copy(queuedCount = count) } }
            .launchIn(viewModelScope)
    }

    private suspend fun buildRows(selfUserId: String, list: List<ChatConversation>) {
        val rows = list.map { convo ->
            val otherId = convo.counterpartId(selfUserId)
            val profile = otherId?.let { id ->
                if (profileCache.containsKey(id)) profileCache[id]
                else profileRepository.fetchById(id).getOrNull().also { profileCache[id] = it }
            }
            Row(convo, profile)
        }
        _state.update { it.copy(loading = false, rows = rows, errorMessage = null) }
    }
}
