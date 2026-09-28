package com.equipseva.app.features.notifications

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.notifications.Notification
import com.equipseva.app.core.data.notifications.NotificationReadPayload
import com.equipseva.app.core.data.notifications.NotificationRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.sync.OutboxEnqueuer
import com.equipseva.app.core.sync.OutboxKinds
import dagger.hilt.android.lifecycle.HiltViewModel
import java.time.Instant
import javax.inject.Inject
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.retryWhen
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull
import kotlinx.serialization.json.Json

/**
 * Backing state for [NotificationsScreen]. Streams the inbox via the
 * realtime-backed [NotificationRepository], surfaces unread counts, and
 * exposes mark-read mutations + pull-to-refresh.
 */
@HiltViewModel
class NotificationsInboxViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val notificationRepository: NotificationRepository,
    private val outboxEnqueuer: OutboxEnqueuer,
    private val json: Json,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val rows: List<Notification> = emptyList(),
        val errorMessage: String? = null,
        /** Changes at every observed identity boundary, including A to B to A. */
        val ownerGeneration: Long = 0,
    ) {
        val unreadCount: Int get() = rows.count { it.isUnread }
        val hasUnread: Boolean get() = unreadCount > 0
    }

    private class Owner(
        val userId: String,
        val generation: Long,
        val scope: CoroutineScope,
    ) {
        var rowsRevision: Long = 0
        var refreshSequence: Long = 0
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    // Public actions and the session collector execute on viewModelScope's
    // Main dispatcher. Identity comparison also fences noncooperative replies.
    private var currentOwner: Owner? = null
    private var nextGeneration = 0L
    private var observedSession = false

    init {
        viewModelScope.launch {
            // Do not collectLatest here: waiting for a noncooperative old fetch
            // would delay the next account's session event and row clearing.
            authRepository.sessionState.collect { session ->
                val userId = (session as? AuthSession.SignedIn)
                    ?.userId?.takeIf(String::isNotBlank)
                val existing = currentOwner
                if (observedSession && userId != null && existing?.userId == userId) {
                    return@collect // email-only and duplicate events retain the stream
                }
                observedSession = true
                existing?.scope?.cancel()
                val generation = ++nextGeneration
                val owner = userId?.let { id ->
                    val job = SupervisorJob(viewModelScope.coroutineContext[Job])
                    Owner(id, generation, CoroutineScope(viewModelScope.coroutineContext + job))
                }
                currentOwner = owner
                _state.value = UiState(
                    loading = owner != null || session == AuthSession.Unknown,
                    ownerGeneration = generation,
                )
                if (owner != null) observe(owner)
            }
        }
    }

    private fun owns(owner: Owner): Boolean = currentOwner === owner

    private fun observe(owner: Owner) {
        owner.scope.launch {
            notificationRepository.observeNotifications(owner.userId)
                // Retry transient realtime failures while this owner remains current.
                .retryWhen { cause, attempt ->
                    if (cause is CancellationException || !owns(owner)) return@retryWhen false
                    val delayMs = minOf(30_000L, 1_000L * (1L shl attempt.coerceAtMost(5).toInt()))
                    _state.update {
                        it.copy(
                            loading = false,
                            errorMessage = "Reconnecting… (${cause.toUserMessage()})",
                        )
                    }
                    delay(delayMs)
                    owns(owner)
                }
                .catch { ex ->
                    if (ex is CancellationException) throw ex
                    if (owns(owner)) {
                        _state.update {
                            it.copy(
                                loading = false,
                                rows = emptyList(),
                                errorMessage = ex.toUserMessage(),
                            )
                        }
                    }
                }
                .collect { rows ->
                    if (owns(owner)) {
                        owner.rowsRevision++
                        _state.update {
                            it.copy(
                                loading = false,
                                rows = rows,
                                errorMessage = null,
                            )
                        }
                    }
                }
        }
    }

    /** A callback from an old rendered row must never navigate after a switch. */
    fun rowForOpen(id: String, expectedGeneration: Long): Notification? {
        val owner = currentOwner ?: return null
        if (owner.generation != expectedGeneration) return null
        return _state.value.rows.firstOrNull { it.id == id }
    }

    /** Pull-to-refresh publishes its query only if a newer stream has not won. */
    fun refresh() {
        val owner = currentOwner ?: return
        if (_state.value.refreshing) return
        val revision = owner.rowsRevision
        val requestId = ++owner.refreshSequence
        _state.update { it.copy(refreshing = true) }
        owner.scope.launch {
            // A plain withTimeoutOrNull around a noncooperative repository
            // suspension can itself remain stuck. Await a separate child so
            // timeout ends the spinner even if that child ignores cancellation.
            val query = owner.scope.async {
                notificationRepository.refreshNotifications(owner.userId)
            }
            val outcome = withTimeoutOrNull(REFRESH_TIMEOUT_MS) {
                query.await()
            }
            if (outcome == null) query.cancel()
            if (!owns(owner) || requestId != owner.refreshSequence) return@launch
            _state.update { current ->
                when {
                    // A newer stream, read action or bulk update superseded
                    // this query. Discard both stale rows and stale errors.
                    owner.rowsRevision != revision -> current.copy(refreshing = false)
                    outcome == null -> current.copy(
                        refreshing = false,
                        errorMessage = "Refresh timed out. Try again.",
                    )
                    outcome.isFailure -> current.copy(
                        refreshing = false,
                        errorMessage = outcome.exceptionOrNull()?.toUserMessage(),
                    )
                    else -> {
                        owner.rowsRevision++
                        current.copy(
                            loading = false,
                            refreshing = false,
                            rows = outcome.getOrThrow(),
                            errorMessage = null,
                        )
                    }
                }
            }
        }
    }

    /**
     * Optimistically mark a single row read. The realtime UPDATE event will
     * re-emit canonical state shortly after, but the local update keeps the
     * UI snappy on slow networks.
     */
    fun markRead(id: String, expectedGeneration: Long? = null) {
        val owner = currentOwner ?: return
        if (expectedGeneration != null && expectedGeneration != owner.generation) return
        val target = _state.value.rows.firstOrNull { it.id == id } ?: return
        if (!target.isUnread) return
        owner.rowsRevision++
        // Optimistically flip the row locally first so the inbox feels
        // snappy regardless of network state. Realtime / next refresh
        // reconciles the canonical read_at.
        _state.update { current ->
            current.copy(
                rows = current.rows.map { row ->
                    if (row.id == id) row.copy(readAt = Instant.now()) else row
                },
            )
        }
        owner.scope.launch {
            val result = notificationRepository.markRead(id)
            if (!owns(owner)) return@launch
            val error = result.exceptionOrNull() ?: return@launch
            if (error is CancellationException) return@launch
            // Capture the source owner. Never serialize a live next-login id.
            val payload = json.encodeToString(
                NotificationReadPayload.serializer(),
                NotificationReadPayload(notificationId = id, userId = owner.userId),
            )
            // Already-started mutations and worker replay still need their
            // independent server-side ownership checks.
            if (owns(owner)) outboxEnqueuer.enqueue(OutboxKinds.NOTIFICATION_READ, payload)
        }
    }

    /** Bulk mark — visible action only when at least one row is unread. */
    fun markAllRead(expectedGeneration: Long? = null) {
        val owner = currentOwner ?: return
        if (expectedGeneration != null && expectedGeneration != owner.generation) return
        val unreadIds = _state.value.rows.filter { it.isUnread }.mapTo(mutableSetOf()) { it.id }
        if (unreadIds.isEmpty()) return
        owner.scope.launch {
            val result = notificationRepository.markAllRead(owner.userId)
            if (!owns(owner)) return@launch
            result.onSuccess {
                val now = Instant.now()
                owner.rowsRevision++
                _state.update { current ->
                    current.copy(rows = current.rows.map { row ->
                        if (row.id in unreadIds && row.isUnread) row.copy(readAt = now) else row
                    })
                }
            }.onFailure { error ->
                if (error !is CancellationException) {
                    _state.update { it.copy(errorMessage = error.toUserMessage()) }
                }
            }
        }
    }

    private companion object {
        const val REFRESH_TIMEOUT_MS = 3_000L
    }
}

