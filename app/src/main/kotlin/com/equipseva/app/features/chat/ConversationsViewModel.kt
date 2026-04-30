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
import kotlinx.coroutines.withTimeoutOrNull
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
        val dummyTitle: String? = null,
    ) {
        val title: String get() = counterpart?.displayName ?: dummyTitle ?: "Conversation"
        val preview: String get() = conversation.lastMessage?.takeIf { it.isNotBlank() } ?: "No messages yet"
    }

    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val rows: List<Row> = emptyList(),
        val queuedCount: Int = 0,
        val errorMessage: String? = null,
        val query: String = "",
    ) {
        val displayedRows: List<Row>
            get() {
                val q = query.trim()
                if (q.isEmpty()) return rows
                return rows.filter { row ->
                    row.title.contains(q, ignoreCase = true) ||
                        row.preview.contains(q, ignoreCase = true)
                }
            }
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    fun onQueryChange(value: String) {
        _state.update { it.copy(query = value) }
    }

    // Cache counterpart profiles so we don't re-fetch on every realtime tick.
    private val profileCache = mutableMapOf<String, Profile?>()

    // Captured once session is known; used by the manual refresh path.
    @Volatile
    private var currentUserId: String? = null

    init {
        viewModelScope.launch {
            val session = authRepository.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .first()
            currentUserId = session.userId
            combine(
                chatRepository.observeConversations(session.userId),
                userBlockRepository.observeBlockedUserIds(),
            ) { list, blocked ->
                list.filter { convo ->
                    val other = convo.counterpartId(session.userId)
                    other == null || other !in blocked
                }
            }
                .onEach { list ->
                    buildRows(session.userId, list)
                    // Data arrived — drop the refresh spinner if one was in flight.
                    _state.update { if (it.refreshing) it.copy(refreshing = false) else it }
                }
                .catch { error ->
                    _state.update {
                        it.copy(loading = false, refreshing = false, errorMessage = error.toUserMessage())
                    }
                }
                .launchIn(viewModelScope)
        }
        outboxDao.observePendingCountByKind(OutboxKinds.CHAT_MESSAGE)
            .onEach { count -> _state.update { it.copy(queuedCount = count) } }
            .launchIn(viewModelScope)
    }

    /**
     * Pull-to-refresh entry point. Runs the same server query the realtime channel triggers;
     * results flow back through [chatRepository.observeConversations] which clears [UiState.refreshing].
     * A 3s safety timeout guarantees the spinner releases even if the network call stalls.
     */
    fun refresh() {
        val userId = currentUserId ?: return
        if (_state.value.refreshing) return
        _state.update { it.copy(refreshing = true) }
        viewModelScope.launch {
            val outcome = withTimeoutOrNull(REFRESH_TIMEOUT_MS) {
                chatRepository.refreshConversations(userId)
            }
            _state.update { current ->
                val err = outcome?.exceptionOrNull()?.toUserMessage()
                current.copy(
                    refreshing = false,
                    errorMessage = err ?: current.errorMessage,
                )
            }
        }
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
        val finalRows = if (rows.isEmpty()) DUMMY_CONVERSATIONS else rows
        _state.update { it.copy(loading = false, rows = finalRows, errorMessage = null) }
    }

    private companion object {
        const val REFRESH_TIMEOUT_MS = 3_000L
    }
}

private fun makeDummyConvo(
    id: String,
    last: String,
    minutesAgo: Long,
    unread: Int,
): ChatConversation = ChatConversation(
    id = id,
    participantUserIds = listOf("self", "other-$id"),
    relatedEntityType = "repair_job",
    relatedEntityId = "dummy-job-$id",
    lastMessage = last,
    lastMessageAtIso = java.time.Instant.now().minusSeconds(minutesAgo * 60).toString(),
    createdAtIso = java.time.Instant.now().minusSeconds(86400).toString(),
    unreadCount = unread,
)

private val DUMMY_CONVERSATIONS: List<ConversationsViewModel.Row> = listOf(
    ConversationsViewModel.Row(
        conversation = makeDummyConvo("c1", "I'll be there by 11. Bring the spare cable.", 8, 2),
        counterpart = null,
        dummyTitle = "Satish Naidu",
    ),
    ConversationsViewModel.Row(
        conversation = makeDummyConvo("c2", "Quote sent — let me know.", 45, 0),
        counterpart = null,
        dummyTitle = "Priyanka Reddy",
    ),
    ConversationsViewModel.Row(
        conversation = makeDummyConvo("c3", "Centrifuge fixed. Belt replaced.", 240, 0),
        counterpart = null,
        dummyTitle = "Lakshmi Devi",
    ),
    ConversationsViewModel.Row(
        conversation = makeDummyConvo("c4", "Rescheduling to tomorrow 9am.", 1440, 1),
        counterpart = null,
        dummyTitle = "Arjun Varma",
    ),
)
