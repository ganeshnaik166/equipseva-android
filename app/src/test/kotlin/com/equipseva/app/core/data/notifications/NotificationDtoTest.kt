package com.equipseva.app.core.data.notifications

import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

/**
 * Inbox rows come in three flavours we have to keep mapping safely:
 *  - new rows with `kind` + `data{deep_link}` (current writer),
 *  - mid-migration rows where the JSONB has the deep link but `kind` is null,
 *  - legacy rows where only `notification_type` + `action_url` are populated.
 *
 * The domain mapping unifies them, so the inbox screen never has to branch on
 * which generation a row came from. Pin every fall-through.
 */
class NotificationDtoTest {

    private val json = Json { ignoreUnknownKeys = true }

    @Test fun `current-generation row maps with kind and deep link`() {
        val dto = json.decodeFromString(
            NotificationDto.serializer(),
            """
            {
              "id": "n1",
              "user_id": "u1",
              "title": "New bid",
              "body": "Engineer Ravi bid ₹1500",
              "kind": "repair_bid_new",
              "data": {
                "deep_link": "equipseva://repair-jobs/job-1",
                "repair_job_id": "job-1",
                "bid_id": "bid-9"
              },
              "sent_at": "2026-05-04T09:00:00Z"
            }
            """.trimIndent(),
        )

        val domain = dto.toDomain()
        assertEquals("n1", domain.id)
        assertEquals("repair_bid_new", domain.kind)
        assertEquals("equipseva://repair-jobs/job-1", domain.deepLink)
        // JSONB primitives are pulled into the flat map.
        assertEquals("job-1", domain.data["repair_job_id"])
        assertEquals("bid-9", domain.data["bid_id"])
        assertEquals(Instant.parse("2026-05-04T09:00:00Z"), domain.sentAt)
        assertTrue(domain.isUnread)
    }

    @Test fun `legacy row falls back to notification_type and action_url`() {
        val dto = json.decodeFromString(
            NotificationDto.serializer(),
            """
            {
              "id": "n2",
              "user_id": "u1",
              "title": "Order shipped",
              "body": "Your order has shipped",
              "notification_type": "order_shipped",
              "action_url": "equipseva://orders/order-1"
            }
            """.trimIndent(),
        )

        val domain = dto.toDomain()
        assertEquals("order_shipped", domain.kind)
        assertEquals("equipseva://orders/order-1", domain.deepLink)
        // No JSONB data on a legacy row.
        assertTrue(domain.data.isEmpty())
    }

    @Test fun `deep_link from JSONB beats action_url when both are present`() {
        val dto = json.decodeFromString(
            NotificationDto.serializer(),
            """
            {
              "id": "n3",
              "user_id": "u1",
              "title": "t",
              "body": "b",
              "kind": "chat_message_new",
              "data": { "deep_link": "equipseva://chat/conv-1" },
              "action_url": "equipseva://stale-fallback"
            }
            """.trimIndent(),
        )
        assertEquals("equipseva://chat/conv-1", dto.toDomain().deepLink)
    }

    @Test fun `blank kind falls through to notification_type`() {
        val dto = json.decodeFromString(
            NotificationDto.serializer(),
            """
            {
              "id": "n4",
              "user_id": "u1",
              "title": "t",
              "body": "b",
              "kind": "   ",
              "notification_type": "order_paid"
            }
            """.trimIndent(),
        )
        assertEquals("order_paid", dto.toDomain().kind)
    }

    @Test fun `both kind and notification_type null leaves kind null`() {
        val dto = json.decodeFromString(
            NotificationDto.serializer(),
            """
            {
              "id": "n5",
              "user_id": "u1",
              "title": "t",
              "body": "b"
            }
            """.trimIndent(),
        )
        assertNull(dto.toDomain().kind)
    }

    @Test fun `read_at populates and flips isUnread`() {
        val dto = json.decodeFromString(
            NotificationDto.serializer(),
            """
            {
              "id": "n6",
              "user_id": "u1",
              "title": "t",
              "body": "b",
              "sent_at": "2026-05-04T09:00:00Z",
              "read_at": "2026-05-04T10:00:00Z"
            }
            """.trimIndent(),
        )
        val domain = dto.toDomain()
        assertEquals(Instant.parse("2026-05-04T10:00:00Z"), domain.readAt)
        assertFalse(domain.isUnread)
    }

    @Test fun `non-primitive JSONB values are skipped from the flat map`() {
        // The data map only carries primitive strings/numbers/booleans. A
        // nested object should not crash the mapper (and not leak into the
        // map either).
        val dto = json.decodeFromString(
            NotificationDto.serializer(),
            """
            {
              "id": "n7",
              "user_id": "u1",
              "title": "t",
              "body": "b",
              "data": {
                "order_id": "ord-9",
                "meta": { "nested": true }
              }
            }
            """.trimIndent(),
        )
        val flat = dto.toDomain().data
        assertEquals("ord-9", flat["order_id"])
        assertFalse("nested object leaked", flat.containsKey("meta"))
    }

    @Test fun `blank action_url and missing deep_link leave deepLink null`() {
        val dto = json.decodeFromString(
            NotificationDto.serializer(),
            """
            {
              "id": "n8",
              "user_id": "u1",
              "title": "t",
              "body": "b",
              "action_url": "  "
            }
            """.trimIndent(),
        )
        assertNull(dto.toDomain().deepLink)
    }

    @Test fun `unparseable timestamps degrade to null instead of throwing`() {
        val dto = json.decodeFromString(
            NotificationDto.serializer(),
            """
            {
              "id": "n9",
              "user_id": "u1",
              "title": "t",
              "body": "b",
              "sent_at": "yesterday",
              "read_at": "soon"
            }
            """.trimIndent(),
        )
        val domain = dto.toDomain()
        assertNull(domain.sentAt)
        assertNull(domain.readAt)
        // Unparseable read_at means the row is still considered unread.
        assertTrue(domain.isUnread)
    }
}
