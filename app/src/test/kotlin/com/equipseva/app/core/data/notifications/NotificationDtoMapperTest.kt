package com.equipseva.app.core.data.notifications

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins [NotificationDto] → [Notification] mapping. Two regions that
 * have repeatedly burned us:
 *
 *   1) The JSONB `data` column is `JsonElement?` on the wire. We
 *      flatten it to `Map<String, String>` for downstream
 *      deep-link routing — non-primitive entries are silently dropped
 *      (nested arrays, objects, nulls) so a route resolver can rely on
 *      `data["repair_job_id"]` being a String or absent.
 *   2) `kind` falls back to the legacy `notification_type` column when
 *      blank, and `deep_link` from data wins over `action_url`. Caught
 *      here so an older row with only `action_url` set still routes.
 */
class NotificationDtoMapperTest {

    private fun dto(
        id: String = "n1",
        title: String = "Bid received",
        body: String = "Engineer offered ₹1,500",
        kind: String? = null,
        notificationType: String? = null,
        data: kotlinx.serialization.json.JsonElement? = null,
        actionUrl: String? = null,
        sentAt: String? = null,
        readAt: String? = null,
    ) = NotificationDto(
        id = id,
        title = title,
        body = body,
        kind = kind,
        notificationType = notificationType,
        data = data,
        actionUrl = actionUrl,
        sentAt = sentAt,
        readAt = readAt,
    )

    @Test fun `populated dto round-trips fields`() {
        val data = JsonObject(
            mapOf(
                "repair_job_id" to JsonPrimitive("j-1"),
                "deep_link" to JsonPrimitive("app://repair/j-1"),
            ),
        )
        val out = dto(
            kind = "repair_bid_new",
            data = data,
            actionUrl = "app://repair/legacy",
            sentAt = "2026-05-21T10:00:00Z",
            readAt = "2026-05-21T10:05:00Z",
        ).toDomain()

        assertEquals("n1", out.id)
        assertEquals("Bid received", out.title)
        assertEquals("repair_bid_new", out.kind)
        assertEquals(mapOf("repair_job_id" to "j-1", "deep_link" to "app://repair/j-1"), out.data)
        // data["deep_link"] wins over action_url.
        assertEquals("app://repair/j-1", out.deepLink)
        assertEquals("2026-05-21T10:00:00Z", out.sentAt?.toString())
        assertEquals("2026-05-21T10:05:00Z", out.readAt?.toString())
        // readAt non-null → row is read.
        assertTrue(!out.isUnread)
    }

    @Test fun `null kind falls back to notification_type legacy column`() {
        val out = dto(kind = null, notificationType = "order_shipped").toDomain()
        assertEquals("order_shipped", out.kind)
    }

    @Test fun `blank kind also falls back to notification_type`() {
        val out = dto(kind = "  ", notificationType = "order_shipped").toDomain()
        assertEquals("order_shipped", out.kind)
    }

    @Test fun `both kind columns blank or null yields null kind`() {
        assertNull(dto(kind = null, notificationType = null).toDomain().kind)
        assertNull(dto(kind = "  ", notificationType = "   ").toDomain().kind)
    }

    @Test fun `null data jsonb maps to empty data map`() {
        val out = dto(data = null).toDomain()
        assertTrue(out.data.isEmpty())
    }

    @Test fun `non-object data jsonb maps to empty data map`() {
        // Defensive: the server contract is an object, but if a row
        // accidentally stored an array or primitive the mapper must
        // still produce a usable Notification rather than crash.
        val out = dto(data = JsonArray(listOf(JsonPrimitive("a")))).toDomain()
        assertTrue(out.data.isEmpty())
    }

    @Test fun `data map drops nested non-primitive entries`() {
        val data = JsonObject(
            mapOf(
                "scalar" to JsonPrimitive("ok"),
                "nested_obj" to JsonObject(mapOf("a" to JsonPrimitive("nope"))),
                "nested_arr" to JsonArray(listOf(JsonPrimitive("nope"))),
                "null_value" to JsonNull,
            ),
        )
        val out = dto(data = data).toDomain()
        // Only the scalar survives the flatten + contentOrNull pass.
        assertEquals(mapOf("scalar" to "ok"), out.data)
    }

    @Test fun `action_url falls back when no deep_link in data`() {
        val data = JsonObject(mapOf("repair_job_id" to JsonPrimitive("j-1")))
        val out = dto(data = data, actionUrl = "app://repair/j-1").toDomain()
        assertEquals("app://repair/j-1", out.deepLink)
    }

    @Test fun `blank action_url folds to null deep link`() {
        val out = dto(actionUrl = "  ").toDomain()
        assertNull(out.deepLink)
    }

    @Test fun `readAt null means unread`() {
        val out = dto(readAt = null).toDomain()
        assertTrue(out.isUnread)
        assertNull(out.readAt)
    }

    @Test fun `malformed sent_at or read_at folds to null instant`() {
        val out = dto(sentAt = "garbage", readAt = "also-garbage").toDomain()
        assertNull(out.sentAt)
        assertNull(out.readAt)
    }
}
