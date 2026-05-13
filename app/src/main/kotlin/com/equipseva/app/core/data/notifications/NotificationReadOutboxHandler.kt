package com.equipseva.app.core.data.notifications

import com.equipseva.app.core.data.entities.OutboxEntryEntity
import com.equipseva.app.core.sync.OutboxKindHandler
import com.equipseva.app.core.sync.classifyOutboxError
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import javax.inject.Inject

/**
 * Drains queued notification mark-read mutations. The optimistic update
 * lives in the VM/UI; this handler is purely about getting the
 * `read_at` column to flip server-side once the network is back so the
 * row doesn't bounce back to unread on the next realtime sync.
 *
 * No owner gate beyond what RLS enforces — `notifications.UPDATE`
 * policy is `auth.uid() = user_id`, so a cross-user drain is rejected
 * at the server and recorded as a 403 (the classifier maps it to
 * GiveUp on the first attempt).
 */
class NotificationReadOutboxHandler @Inject constructor(
    private val notificationRepository: NotificationRepository,
    private val json: Json,
) : OutboxKindHandler {

    override suspend fun handle(entry: OutboxEntryEntity): OutboxKindHandler.Outcome {
        val payload = runCatching {
            json.decodeFromString<NotificationReadPayload>(entry.payload)
        }.getOrElse {
            return OutboxKindHandler.Outcome.GiveUp("Malformed payload: ${it.message}")
        }
        return notificationRepository.markRead(payload.notificationId).fold(
            onSuccess = { OutboxKindHandler.Outcome.Success },
            onFailure = ::classifyOutboxError,
        )
    }
}

@Serializable
data class NotificationReadPayload(
    val notificationId: String,
)
