package com.equipseva.app.core.push

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

/**
 * Pins the per-push notify-id resolution. Chat messages collapse on
 * conversationId so a second message in the same thread replaces
 * the previous push instead of stacking; all other kinds use the
 * FCM messageId so each push surfaces independently.
 *
 * Two regions worth defending:
 *   * Both `conversationId` (camelCase, legacy) and `conversation_id`
 *     (snake_case, current) accepted — server rename mid-flight
 *     shouldn't lose the collapse behaviour for already-deployed
 *     clients.
 *   * Non-chat kinds (or chat with missing convo id) fall back to
 *     messageId hashing — each surfaces independently.
 */
class ResolveNotifyIdTest {

    @Test fun `chat_message with conversation_id (snake_case) collapses on convo`() {
        val id = resolveNotifyId(
            kind = "chat_message",
            data = mapOf("conversation_id" to "conv-1"),
            messageId = "fcm-1",
        )
        // The notifyId is stable for the same convoId.
        assertEquals("chat:conv-1".hashCode(), id)
    }

    @Test fun `chat_message with conversationId (camelCase) also collapses`() {
        val id = resolveNotifyId(
            kind = "chat_message",
            data = mapOf("conversationId" to "conv-1"),
            messageId = "fcm-1",
        )
        assertEquals("chat:conv-1".hashCode(), id)
    }

    @Test fun `chat_message in same conversation produces the same notifyId`() {
        // Two messages in conv-1 → identical notifyId → second
        // replaces first in the system tray.
        val first = resolveNotifyId(
            kind = "chat_message",
            data = mapOf("conversation_id" to "conv-1"),
            messageId = "fcm-1",
        )
        val second = resolveNotifyId(
            kind = "chat_message",
            data = mapOf("conversation_id" to "conv-1"),
            messageId = "fcm-2",  // Different FCM messageId, same conv.
        )
        assertEquals(first, second)
    }

    @Test fun `chat_message in different conversation produces a different notifyId`() {
        val a = resolveNotifyId(
            kind = "chat_message",
            data = mapOf("conversation_id" to "conv-A"),
            messageId = "fcm-1",
        )
        val b = resolveNotifyId(
            kind = "chat_message",
            data = mapOf("conversation_id" to "conv-B"),
            messageId = "fcm-1",
        )
        assertNotEquals(a, b)
    }

    @Test fun `chat_message with both id shapes prefers camelCase (legacy wins)`() {
        // The Elvis ordering is `data["conversationId"] ?: data["conversation_id"]`.
        // Pin the precedence so a server bug that ships both keys
        // doesn't silently flip the collapse target.
        val id = resolveNotifyId(
            kind = "chat_message",
            data = mapOf(
                "conversationId" to "camelCase-conv",
                "conversation_id" to "snake_conv",
            ),
            messageId = "fcm-1",
        )
        assertEquals("chat:camelCase-conv".hashCode(), id)
    }

    @Test fun `chat_message with missing conversation id falls back to messageId`() {
        val id = resolveNotifyId(
            kind = "chat_message",
            data = emptyMap(),
            messageId = "fcm-42",
        )
        assertEquals("fcm-42".hashCode(), id)
    }

    @Test fun `non-chat kind always uses messageId regardless of convo data`() {
        // Defensive — even if the data happens to carry a
        // conversation_id, a non-chat kind must NOT collapse.
        val id = resolveNotifyId(
            kind = "repair_bid_new",
            data = mapOf("conversation_id" to "conv-1"),
            messageId = "fcm-1",
        )
        assertEquals("fcm-1".hashCode(), id)
    }

    @Test fun `null messageId falls back to (null hash) - non-zero stable value`() {
        // String?.hashCode() on null is 0 — pin so the no-id path
        // produces a deterministic constant rather than crashing.
        val id = resolveNotifyId(
            kind = "repair_bid_new",
            data = emptyMap(),
            messageId = null,
        )
        assertEquals(0, id)
    }
}
