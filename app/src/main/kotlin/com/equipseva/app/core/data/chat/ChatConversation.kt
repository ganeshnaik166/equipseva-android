package com.equipseva.app.core.data.chat

import com.equipseva.app.core.util.parseInstantOrNull
import java.time.Instant

data class ChatConversation(
    val id: String,
    val participantUserIds: List<String>,
    val relatedEntityType: String?,
    val relatedEntityId: String?,
    val lastMessage: String?,
    val lastMessageAtIso: String?,
    val createdAtIso: String?,
    val unreadCount: Int = 0,
) {
    val lastMessageInstant: Instant?
        get() = lastMessageAtIso.parseInstantOrNull()

    fun counterpartId(selfUserId: String): String? =
        participantUserIds.firstOrNull { it != selfUserId }
}

internal fun ConversationDto.toDomain(): ChatConversation = ChatConversation(
    id = id,
    participantUserIds = participantUserIds.orEmpty(),
    relatedEntityType = relatedEntityType,
    relatedEntityId = relatedEntityId,
    lastMessage = lastMessage,
    lastMessageAtIso = lastMessageAt,
    createdAtIso = createdAt,
)
