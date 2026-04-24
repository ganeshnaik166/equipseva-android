package com.equipseva.app.core.data.chat

import java.time.Instant
import java.time.format.DateTimeParseException

data class ChatMessage(
    val id: String,
    val conversationId: String,
    val senderUserId: String,
    val message: String,
    val attachments: List<String>,
    val isRead: Boolean,
    val createdAtIso: String?,
    val deletedAtIso: String? = null,
) {
    val createdAtInstant: Instant?
        get() = createdAtIso?.let {
            try {
                Instant.parse(it)
            } catch (_: DateTimeParseException) {
                null
            } catch (_: IllegalArgumentException) {
                null
            }
        }

    /** True when the sender has soft-deleted this message. Body and attachments are hidden. */
    val isDeleted: Boolean
        get() = deletedAtIso != null
}

internal fun MessageDto.toDomain(): ChatMessage = ChatMessage(
    id = id,
    conversationId = conversationId,
    senderUserId = senderUserId,
    message = message.orEmpty(),
    attachments = attachments.orEmpty(),
    isRead = isRead ?: false,
    createdAtIso = createdAt,
    deletedAtIso = deletedAt,
)
