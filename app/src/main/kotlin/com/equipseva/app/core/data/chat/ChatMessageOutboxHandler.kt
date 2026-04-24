package com.equipseva.app.core.data.chat

import com.equipseva.app.core.data.entities.OutboxEntryEntity
import com.equipseva.app.core.sync.OutboxKindHandler
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import javax.inject.Inject

/**
 * Drains queued chat messages via the repository's normal send path so the
 * conversation's last_message/last_message_at get patched identically to the
 * online flow. Any failure becomes [OutboxKindHandler.Outcome.Retry]; the
 * worker's [OutboxWorker.MAX_ATTEMPTS] cap drops a poison payload.
 */
class ChatMessageOutboxHandler @Inject constructor(
    private val chatRepository: ChatRepository,
    private val json: Json,
) : OutboxKindHandler {

    override suspend fun handle(entry: OutboxEntryEntity): OutboxKindHandler.Outcome {
        val payload = runCatching { json.decodeFromString<ChatMessagePayload>(entry.payload) }
            .getOrElse { return OutboxKindHandler.Outcome.GiveUp("Malformed payload: ${it.message}") }
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
