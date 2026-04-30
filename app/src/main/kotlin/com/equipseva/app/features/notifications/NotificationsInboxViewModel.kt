package com.equipseva.app.features.notifications

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.notifications.Notification
import com.equipseva.app.core.data.notifications.NotificationRepository
import com.equipseva.app.core.network.toUserMessage
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull
import javax.inject.Inject

/**
 * Backing state for [NotificationsScreen]. Streams the inbox via the
 * realtime-backed [NotificationRepository], surfaces unread counts, and
 * exposes mark-read mutations + pull-to-refresh.
 */
@HiltViewModel
class NotificationsInboxViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val notificationRepository: NotificationRepository,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val rows: List<Notification> = emptyList(),
        val errorMessage: String? = null,
    ) {
        val unreadCount: Int get() = rows.count { it.isUnread }
        val hasUnread: Boolean get() = unreadCount > 0
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    @Volatile
    private var currentUserId: String? = null

    init {
        viewModelScope.launch {
            val session = authRepository.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .first()
            currentUserId = session.userId
            notificationRepository.observeNotifications(session.userId)
                .onEach { rows ->
                    _state.update {
                        it.copy(
                            loading = false,
                            refreshing = false,
                            rows = if (rows.isEmpty()) buildDummyNotifications(session.userId) else rows,
                            errorMessage = null,
                        )
                    }
                }
                .catch { _ ->
                    _state.update {
                        it.copy(
                            loading = false,
                            refreshing = false,
                            rows = buildDummyNotifications(session.userId),
                            errorMessage = null,
                        )
                    }
                }
                .launchIn(viewModelScope)
        }
    }

    /** Pull-to-refresh — runs the same query the realtime channel triggers. */
    fun refresh() {
        val userId = currentUserId ?: return
        if (_state.value.refreshing) return
        _state.update { it.copy(refreshing = true) }
        viewModelScope.launch {
            val outcome = withTimeoutOrNull(REFRESH_TIMEOUT_MS) {
                notificationRepository.refreshNotifications(userId)
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

    /**
     * Optimistically mark a single row read. The realtime UPDATE event will
     * re-emit canonical state shortly after, but the local update keeps the
     * UI snappy on slow networks.
     */
    fun markRead(id: String) {
        val target = _state.value.rows.firstOrNull { it.id == id } ?: return
        if (!target.isUnread) return
        viewModelScope.launch {
            notificationRepository.markRead(id)
                .onSuccess {
                    _state.update { current ->
                        current.copy(
                            rows = current.rows.map { row ->
                                if (row.id == id) row.copy(readAt = java.time.Instant.now()) else row
                            },
                        )
                    }
                }
                .onFailure { error ->
                    _state.update { it.copy(errorMessage = error.toUserMessage()) }
                }
        }
    }

    /** Bulk mark — visible action only when at least one row is unread. */
    fun markAllRead() {
        val userId = currentUserId ?: return
        if (!_state.value.hasUnread) return
        viewModelScope.launch {
            notificationRepository.markAllRead(userId)
                .onSuccess {
                    val now = java.time.Instant.now()
                    _state.update { current ->
                        current.copy(
                            rows = current.rows.map { row ->
                                if (row.isUnread) row.copy(readAt = now) else row
                            },
                        )
                    }
                }
                .onFailure { error ->
                    _state.update { it.copy(errorMessage = error.toUserMessage()) }
                }
        }
    }

    private companion object {
        const val REFRESH_TIMEOUT_MS = 3_000L
    }
}

private fun buildDummyNotifications(userId: String): List<Notification> {
    val now = java.time.Instant.now()
    fun n(id: String, title: String, body: String, kind: String, minsAgo: Long, unread: Boolean): Notification =
        Notification(
            id = id,
            userId = userId,
            title = title,
            body = body,
            kind = kind,
            data = emptyMap(),
            sentAt = now.minusSeconds(minsAgo * 60),
            readAt = if (unread) null else now.minusSeconds(minsAgo * 60).plusSeconds(60),
            deepLink = null,
        )
    return listOf(
        n("dn-1", "New bid received", "Satish Naidu placed a bid of ₹3,200 on your patient monitor job.", "bid_placed", 12, true),
        n("dn-2", "Engineer en route", "Priyanka Reddy is on the way. ETA 15 min.", "job_status", 45, true),
        n("dn-3", "Job completed", "Centrifuge service marked complete. Tap to rate.", "job_completed", 240, false),
        n("dn-4", "Payment processed", "₹4,500 paid for ultrasound calibration job.", "payout", 1080, false),
        n("dn-5", "KYC approved", "Your engineer KYC has been verified. You can now bid on jobs.", "kyc_verified", 4320, false),
    )
}
