package com.equipseva.app.core.data.chat

import com.equipseva.app.core.data.entities.OutboxEntryEntity
import com.equipseva.app.core.sync.OutboxKindHandler
import com.equipseva.app.core.sync.classifyOutboxError
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import javax.inject.Inject

/**
 * Drains queued chat messages via the repository's normal send path so the
 * conversation's last_message/last_message_at get patched identically to the
 * online flow. Any failure becomes [OutboxKindHandler.Outcome.Retry]; the
 * worker's [OutboxWorker.MAX_ATTEMPTS] cap drops a poison payload.
 *
 * Owner gate: the payload carries the original `senderUserId`. Outbox rows
 * outlive sign-out / sign-in, so on a shared device user B could otherwise
 * drain user A's queued writes — best case `chat_messages` RLS rejects the
 * insert (message silently lost), worst case a permissive RLS attributes the
 * message to the wrong user. We compare the persisted `senderUserId` against
 * the current `auth.uid` and:
 *   - `Retry` when there is no session (signed out — try again next flush).
 *   - `GiveUp` on a real mismatch (different user signed in — don't loop
 *     until poison; just drop).
 *
 * Peer handlers (repair bid, job status) are safe without this check because
 * their repositories source the user id from `client.auth.currentUser` at
 * call time and never trust a payload-embedded user id.
 */
class ChatMessageOutboxHandler @Inject constructor(
    private val chatRepository: ChatRepository,
    private val supabase: SupabaseClient,
    private val json: Json,
) : OutboxKindHandler {

    override suspend fun handle(entry: OutboxEntryEntity): OutboxKindHandler.Outcome {
        val payload = runCatching { json.decodeFromString<ChatMessagePayload>(entry.payload) }
            .getOrElse { return OutboxKindHandler.Outcome.GiveUp("Malformed payload: ${it.message}") }

        val currentUid = supabase.auth.currentUserOrNull()?.id
            ?: return OutboxKindHandler.Outcome.Retry(
                IllegalStateException("No auth session — deferring chat drain"),
            )
        val mismatch = chatMessageSenderMismatchReason(payload.senderUserId, currentUid)
        if (mismatch != null) {
            return OutboxKindHandler.Outcome.GiveUp(mismatch)
        }

        // Bound the send to 15s. A flaky link can hang the supabase-kt
        // client indefinitely; without a cap this worker would block
        // until poison-drop after 5 attempts. 15s is plenty for a text
        // payload + optional attachment-URL row insert.
        val result = try {
            kotlinx.coroutines.withTimeout(SEND_TIMEOUT_MS) {
                chatRepository.sendMessage(
                    conversationId = payload.conversationId,
                    senderUserId = payload.senderUserId,
                    message = payload.body,
                    attachments = payload.attachments,
                )
            }
        } catch (timeout: kotlinx.coroutines.TimeoutCancellationException) {
            return OutboxKindHandler.Outcome.Retry(timeout)
        }
        return result.fold(
            onSuccess = { OutboxKindHandler.Outcome.Success },
            onFailure = ::classifyOutboxError,
        )
    }

    private companion object {
        const val SEND_TIMEOUT_MS = 15_000L
    }
}

@Serializable
data class ChatMessagePayload(
    val conversationId: String,
    val senderUserId: String,
    val body: String,
    val attachments: List<String> = emptyList(),
)

/**
 * Shared-device gate for the chat-message drain. Returns null when the
 * payload-embedded sender matches the currently-signed-in user and a
 * give-up reason string otherwise. Pure / non-suspend so the policy can
 * be exercised without standing up the supabase client.
 *
 * Pinned semantics:
 *   * Identity match → null (allow).
 *   * Mismatch → reason string with both ids embedded for the ops log.
 *   * Case-sensitive comparison — UUIDs are normalised lowercase on the
 *     wire, but pin so a refactor that uppercases either side doesn't
 *     silently start dropping its own messages.
 *   * Both empty strings count as a match (defensive — should never
 *     happen, but pin total shape rather than NPE).
 */
internal fun chatMessageSenderMismatchReason(
    senderUserId: String,
    currentUserId: String,
): String? = if (senderUserId == currentUserId) {
    null
} else {
    "Sender mismatch: queued as $senderUserId, current auth is $currentUserId"
}
