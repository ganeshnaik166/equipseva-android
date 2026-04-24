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
 * Ownership gate: the persisted `senderUserId` is the user who originally
 * queued the message. If a different user is signed in at drain time
 * (sign-out + sign-in on shared device), we refuse to flush — otherwise the
 * insert would either get rejected by chat_messages RLS (best case, message
 * silently lost) or, on permissive RLS, attribute the message to the wrong
 * user. GiveUp drops the entry instead of looping until poison.
 */
class ChatMessageOutboxHandler @Inject constructor(
    private val chatRepository: ChatRepository,
    private val supabase: SupabaseClient,
    private val json: Json,
) : OutboxKindHandler {

    override suspend fun handle(entry: OutboxEntryEntity): OutboxKindHandler.Outcome {
        val payload = runCatching { json.decodeFromString<ChatMessagePayload>(entry.payload) }
            .getOrElse { return OutboxKindHandler.Outcome.GiveUp("Malformed payload: ${it.message}") }

        val currentUserId = supabase.auth.currentUserOrNull()?.id
        if (currentUserId == null) {
            return OutboxKindHandler.Outcome.Retry(IllegalStateException("No signed-in user"))
        }
        if (currentUserId != payload.senderUserId) {
            return OutboxKindHandler.Outcome.GiveUp(
                "Drain skipped: queued for sender=${payload.senderUserId} but current user=$currentUserId",
            )
        }

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
