package com.equipseva.app.core.data.notifications

import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.entities.OutboxEntryEntity
import com.equipseva.app.core.sync.OutboxKindHandler
import com.equipseva.app.core.sync.classifyOutboxError
import kotlinx.coroutines.flow.first
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import javax.inject.Inject

/**
 * Drains queued notification mark-read mutations. The optimistic update
 * lives in the VM/UI; this handler is purely about getting the
 * `read_at` column to flip server-side once the network is back so the
 * row doesn't bounce back to unread on the next realtime sync.
 *
 * Owner gate: when the queued payload carries a `userId`, the handler
 * compares it to the currently-signed-in user before draining. If a
 * different account is signed in (shared device case), the row is
 * dropped with GiveUp so the next user doesn't waste a retry-budget
 * attempt round-tripping a row that RLS will reject anyway. Rows
 * enqueued before this field existed have `userId = null` and fall
 * through to RLS-only protection — same behavior as before.
 */
class NotificationReadOutboxHandler @Inject constructor(
    private val notificationRepository: NotificationRepository,
    private val authRepository: AuthRepository,
    private val json: Json,
) : OutboxKindHandler {

    override suspend fun handle(entry: OutboxEntryEntity): OutboxKindHandler.Outcome {
        val payload = runCatching {
            json.decodeFromString<NotificationReadPayload>(entry.payload)
        }.getOrElse {
            return OutboxKindHandler.Outcome.GiveUp("Malformed payload: ${it.message}")
        }
        val owner = payload.userId
        if (owner != null) {
            val current = authRepository.sessionState.first()
            val uid = (current as? AuthSession.SignedIn)?.userId
            if (uid != owner) {
                return OutboxKindHandler.Outcome.GiveUp(
                    "Cross-user notif read drop (queued=$owner, current=$uid)",
                )
            }
        }
        // Round 437 — bound the RPC like the chat / bid / job-status
        // handlers do. Without it, a hung TLS connection burns the full
        // MAX_ATTEMPTS retry budget on the same broken socket and the
        // mark-read poison-drops without surfacing why. 15s matches
        // ChatMessageOutboxHandler's SEND_TIMEOUT_MS.
        return runCatching {
            kotlinx.coroutines.withTimeout(MARK_READ_TIMEOUT_MS) {
                notificationRepository.markRead(payload.notificationId)
            }
        }.fold(
            onSuccess = { result ->
                result.fold(
                    onSuccess = { OutboxKindHandler.Outcome.Success },
                    onFailure = ::classifyOutboxError,
                )
            },
            onFailure = ::classifyOutboxError,
        )
    }

    companion object {
        private const val MARK_READ_TIMEOUT_MS = 15_000L
    }
}

@Serializable
data class NotificationReadPayload(
    val notificationId: String,
    // Optional + defaulted so rows queued before this field existed still
    // decode. New writes always set it; absence triggers RLS-only fallback.
    val userId: String? = null,
)
