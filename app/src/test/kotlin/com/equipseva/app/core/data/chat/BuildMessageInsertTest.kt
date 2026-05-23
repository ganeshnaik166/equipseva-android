package com.equipseva.app.core.data.chat

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins the chat-send payload composition. Two regions worth
 * defending:
 *
 *   1) The 4000-char body cap matches the server CHECK on
 *      chat_messages.message. The ChatViewModel UI clamps too, but
 *      the outbox replay path lives outside the VM — pin the repo-
 *      side gate so a draft that survived process death gets clamped
 *      on flush.
 *   2) Empty attachments list folds to null so a text-only message
 *      doesn't carry an empty `attachments: []` array on every wire.
 */
class BuildMessageInsertTest {

    @Test fun `text-only message folds attachments to null`() {
        val dto = buildMessageInsert(
            conversationId = "c-1",
            senderUserId = "u-1",
            message = "hi",
            attachments = emptyList(),
        )
        assertEquals("c-1", dto.conversationId)
        assertEquals("u-1", dto.senderUserId)
        assertEquals("hi", dto.message)
        assertNull(dto.attachments)
    }

    @Test fun `non-empty attachments list passes through`() {
        val dto = buildMessageInsert(
            conversationId = "c-1",
            senderUserId = "u-1",
            message = "look at this",
            attachments = listOf("k/photo.jpg", "k/doc.pdf"),
        )
        assertEquals(listOf("k/photo.jpg", "k/doc.pdf"), dto.attachments)
    }

    @Test fun `message at exactly 4000 chars passes through unchanged`() {
        val cap = "x".repeat(4000)
        val dto = buildMessageInsert("c-1", "u-1", cap)
        assertEquals(4000, dto.message.length)
    }

    @Test fun `message over 4000 chars is truncated to the server cap`() {
        val long = "y".repeat(6000)
        val dto = buildMessageInsert("c-1", "u-1", long)
        assertEquals(4000, dto.message.length)
    }

    @Test fun `empty body is preserved as-is (caller decides)`() {
        // The repo doesn't reject empty — the ChatViewModel UI gates
        // empty-draft submission via canSend. Pin so a future "reject
        // here" change is reviewed.
        val dto = buildMessageInsert("c-1", "u-1", "")
        assertEquals("", dto.message)
    }

    @Test fun `default attachments arg is empty list (folds to null)`() {
        // Pin the default-arg convenience — most callers don't pass
        // attachments at all.
        val dto = buildMessageInsert(
            conversationId = "c-1",
            senderUserId = "u-1",
            message = "no attachments",
        )
        assertNull(dto.attachments)
    }
}
