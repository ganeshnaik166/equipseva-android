package com.equipseva.app.core.data.chat

import com.equipseva.app.core.data.entities.OutboxEntryEntity
import com.equipseva.app.core.sync.OutboxKindHandler
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
        senderGateDecision(payload.senderUserId, currentUid)?.let { return it }

        return chatRepository.sendMessage(
            conversationId = payload.conversationId,
            senderUserId = payload.senderUserId,
            message = payload.body,
            attachments = payload.attachments,
        ).fold(
            onSuccess = { OutboxKindHandler.Outcome.Success },
            onFailure = { OutboxKindHandler.Outcome.Retry(it) },
        )
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
 * Pure owner-gate decision for a queued chat drain. Pulled out so the
 * Retry-vs-GiveUp-vs-proceed branches are unit-testable without standing
 * up a SupabaseClient.
 *
 * Returns:
 *  - [OutboxKindHandler.Outcome.Retry] when no user is currently signed in
 *    (the next flush, after the user signs back in, will reconsider).
 *  - [OutboxKindHandler.Outcome.GiveUp] on a real mismatch (different user
 *    signed in — drop rather than loop until poison).
 *  - `null` when the caller should proceed with the actual send.
 */
internal fun senderGateDecision(
    payloadSenderUserId: String,
    currentUid: String?,
): OutboxKindHandler.Outcome? {
    if (currentUid == null) {
        return OutboxKindHandler.Outcome.Retry(
            IllegalStateException("No auth session — deferring chat drain"),
        )
    }
    if (currentUid != payloadSenderUserId) {
        return OutboxKindHandler.Outcome.GiveUp(
            "Sender mismatch: queued as $payloadSenderUserId, current auth is $currentUid",
        )
    }
    return null
}
