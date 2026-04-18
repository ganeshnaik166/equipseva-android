package com.equipseva.app.core.data.chat

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class ConversationDto(
    val id: String,
    @SerialName("participant_user_ids") val participantUserIds: List<String>? = null,
    @SerialName("related_entity_type") val relatedEntityType: String? = null,
    @SerialName("related_entity_id") val relatedEntityId: String? = null,
    @SerialName("last_message") val lastMessage: String? = null,
    @SerialName("last_message_at") val lastMessageAt: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
)

@Serializable
internal data class ConversationInsertDto(
    @SerialName("participant_user_ids") val participantUserIds: List<String>,
    @SerialName("related_entity_type") val relatedEntityType: String? = null,
    @SerialName("related_entity_id") val relatedEntityId: String? = null,
)
