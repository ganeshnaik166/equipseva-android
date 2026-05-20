package com.equipseva.app.core.data.chat

import androidx.compose.runtime.Immutable
import com.equipseva.app.core.util.parseInstantOrNull
import java.time.Instant

// Round 461 — @Immutable lets Compose skip ConversationRow recomposition
// when conversation.equals(prev). Without it the participantUserIds
// List<String> field flagged the class as Unstable, so every realtime
// tick / unread-count update on the inbox re-rendered every row.
@Immutable
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
