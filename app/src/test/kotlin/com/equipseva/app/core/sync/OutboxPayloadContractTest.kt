package com.equipseva.app.core.sync

import com.equipseva.app.core.data.chat.ChatMessagePayload
import com.equipseva.app.core.data.notifications.NotificationReadPayload
import com.equipseva.app.core.data.repair.JobStatusPayload
import com.equipseva.app.core.data.repair.RepairBidPayload
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Contract tests for the four non-photo outbox payloads. These rows
 * persist into the DB and survive app upgrades — a stealth field
 * rename or default-value removal would orphan every queued row in
 * the wild (decode fails → poison-drop budget burns).
 *
 * Round-trip every payload through Json.encodeToString → decodeFromString
 * so an accidental @SerialName drift surfaces in CI.
 *
 * Owner-gate field nullability matters across the set:
 *   * NotificationReadPayload.userId — null for pre-v1 queued rows.
 *   * JobStatusPayload.actorUserId — null for pre-PR owner-gate rows
 *     (handler GiveUp's on null).
 *   * RepairBidPayload.engineerUserId — null for pre-owner-gate rows.
 *   * ChatMessagePayload has no nullable owner — senderUserId is
 *     required from day one.
 */
class OutboxPayloadContractTest {

    private val json = Json { ignoreUnknownKeys = true }

    // ---- ChatMessagePayload ----

    @Test fun `ChatMessagePayload round-trips with attachments`() {
        val original = ChatMessagePayload(
            conversationId = "c1",
            senderUserId = "u1",
            body = "hi",
            attachments = listOf("k/a.jpg", "k/b.jpg"),
        )
        val encoded = json.encodeToString(ChatMessagePayload.serializer(), original)
        val decoded = json.decodeFromString(ChatMessagePayload.serializer(), encoded)
        assertEquals(original, decoded)
    }

    @Test fun `ChatMessagePayload attachments defaults to empty list`() {
        // Pre-attachments queued rows should still decode without the
        // attachments field — pin the default.
        val payload = json.decodeFromString(
            ChatMessagePayload.serializer(),
            """{"conversationId":"c1","senderUserId":"u1","body":"hi"}""",
        )
        assertEquals(emptyList<String>(), payload.attachments)
    }

    // ---- JobStatusPayload ----

    @Test fun `JobStatusPayload round-trips with all fields`() {
        val original = JobStatusPayload(
            jobId = "j1",
            newStatus = "Completed",
            startedAtEpochMs = 1_700_000_000_000L,
            completedAtEpochMs = 1_700_000_900_000L,
            actorUserId = "u1",
            cancellationReason = "no-show",
        )
        val encoded = json.encodeToString(JobStatusPayload.serializer(), original)
        val decoded = json.decodeFromString(JobStatusPayload.serializer(), encoded)
        assertEquals(original, decoded)
    }

    @Test fun `JobStatusPayload actorUserId defaults to null for legacy rows`() {
        val payload = json.decodeFromString(
            JobStatusPayload.serializer(),
            """{"jobId":"j1","newStatus":"InProgress"}""",
        )
        assertNull(payload.actorUserId)
        assertNull(payload.cancellationReason)
        assertNull(payload.startedAtEpochMs)
        assertNull(payload.completedAtEpochMs)
    }

    // ---- RepairBidPayload ----

    @Test fun `RepairBidPayload round-trips with all fields`() {
        val original = RepairBidPayload(
            jobId = "j1",
            amountRupees = 2500.0,
            etaHours = 4,
            note = "On my way",
            engineerUserId = "u1",
        )
        val encoded = json.encodeToString(RepairBidPayload.serializer(), original)
        val decoded = json.decodeFromString(RepairBidPayload.serializer(), encoded)
        assertEquals(original, decoded)
    }

    @Test fun `RepairBidPayload engineerUserId defaults to null for legacy rows`() {
        // Pre-owner-gate rows queued without the engineer id; handler
        // falls through to placeBid which still RLS-gates on engineer_user_id.
        val payload = json.decodeFromString(
            RepairBidPayload.serializer(),
            """{"jobId":"j1","amountRupees":2500.0}""",
        )
        assertNull(payload.engineerUserId)
        assertNull(payload.etaHours)
        assertNull(payload.note)
    }

    // ---- NotificationReadPayload ----

    @Test fun `NotificationReadPayload round-trips`() {
        val original = NotificationReadPayload(
            notificationId = "n1",
            userId = "u1",
        )
        val encoded = json.encodeToString(NotificationReadPayload.serializer(), original)
        val decoded = json.decodeFromString(NotificationReadPayload.serializer(), encoded)
        assertEquals(original, decoded)
    }

    @Test fun `NotificationReadPayload userId defaults to null for legacy rows`() {
        val payload = json.decodeFromString(
            NotificationReadPayload.serializer(),
            """{"notificationId":"n1"}""",
        )
        assertNull(payload.userId)
    }
}
