package com.equipseva.app.core.data.notifications

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import java.time.Instant

@Serializable
internal data class NotificationDto(
    val id: String,
    @SerialName("user_id") val userId: String,
    val title: String,
    val body: String,
    val kind: String? = null,
    /**
     * Legacy column from the original schema. We surface it as a fallback
     * when `kind` is empty so older rows don't show as untyped.
     */
    @SerialName("notification_type") val notificationType: String? = null,
    val data: JsonElement? = null,
    @SerialName("action_url") val actionUrl: String? = null,
    @SerialName("sent_at") val sentAt: String? = null,
    @SerialName("read_at") val readAt: String? = null,
) {
    fun toDomain(): Notification {
        val flatData = (data as? JsonObject).orEmpty().mapNotNull { (key, value) ->
            (value as? JsonPrimitive)?.contentOrNull?.let { key to it }
        }.toMap()
        // `deep_link` from the JSONB blob wins; fall back to the legacy
        // `action_url` column so server code that hasn't migrated yet still
        // routes correctly.
        val deepLink = flatData["deep_link"] ?: actionUrl
        return Notification(
            id = id,
            userId = userId,
            title = title,
            body = body,
            kind = kind?.takeIf { it.isNotBlank() } ?: notificationType?.takeIf { it.isNotBlank() },
            data = flatData,
            sentAt = sentAt?.let { runCatching { Instant.parse(it) }.getOrNull() },
            readAt = readAt?.let { runCatching { Instant.parse(it) }.getOrNull() },
            deepLink = deepLink?.takeIf { it.isNotBlank() },
        )
    }
}

private fun JsonObject?.orEmpty(): Map<String, JsonElement> = this ?: emptyMap()
