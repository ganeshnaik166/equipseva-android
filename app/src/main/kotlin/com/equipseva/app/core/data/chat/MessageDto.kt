package com.equipseva.app.core.data.chat

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class MessageDto(
    val id: String,
    @SerialName("conversation_id") val conversationId: String,
    @SerialName("sender_user_id") val senderUserId: String,
    val message: String? = null,
    val attachments: List<String>? = null,
    @SerialName("is_read") val isRead: Boolean? = null,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("deleted_at") val deletedAt: String? = null,
    @SerialName("edited_at") val editedAt: String? = null,
)

@Serializable
internal data class MessageInsertDto(
    @SerialName("conversation_id") val conversationId: String,
    @SerialName("sender_user_id") val senderUserId: String,
    val message: String,
    val attachments: List<String>? = null,
)

@Serializable
internal data class UnreadRowDto(
    @SerialName("conversation_id") val conversationId: String,
)
