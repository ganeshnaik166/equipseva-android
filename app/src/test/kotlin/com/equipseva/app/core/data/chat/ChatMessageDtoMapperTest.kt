package com.equipseva.app.core.data.chat

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins [MessageDto] → [ChatMessage] mapping. Chat rows render hundreds
 * at a time and the @Immutable annotation depends on stable List<String>
 * defaults — the mapper's `.orEmpty()` defaults are what enforce that.
 * A regression that swapped any default would either crash a row paint
 * (null attachments → !!) or invalidate the Compose skipping
 * optimisation (different empty list identities each recompose).
 */
class ChatMessageDtoMapperTest {

    private fun emptyDto(
        id: String = "m1",
        conversationId: String = "c1",
        senderUserId: String = "u1",
    ) = MessageDto(id = id, conversationId = conversationId, senderUserId = senderUserId)

    @Test fun `all-null dto maps to safe defaults`() {
        val msg = emptyDto().toDomain()

        assertEquals("m1", msg.id)
        assertEquals("c1", msg.conversationId)
        assertEquals("u1", msg.senderUserId)
        // null message body → empty string (renders as a 0-length bubble
        // rather than crashing the row composable on a null assertion).
        assertEquals("", msg.message)
        assertTrue(msg.attachments.isEmpty())
        // unread default — newly inserted rows that race the
        // is_read=false trigger should still surface as unread.
        assertFalse(msg.isRead)
        assertNull(msg.createdAtIso)
        assertNull(msg.deletedAtIso)
        assertNull(msg.editedAtIso)
    }

    @Test fun `populated dto round-trips fields`() {
        val msg = emptyDto().copy(
            message = "hello",
            attachments = listOf("k/a.jpg", "k/b.jpg"),
            isRead = true,
            createdAt = "2026-05-21T10:00:00Z",
            deletedAt = "2026-05-21T10:05:00Z",
            editedAt = "2026-05-21T10:02:00Z",
        ).toDomain()

        assertEquals("hello", msg.message)
        assertEquals(listOf("k/a.jpg", "k/b.jpg"), msg.attachments)
        assertTrue(msg.isRead)
        assertEquals("2026-05-21T10:00:00Z", msg.createdAtIso)
        assertEquals("2026-05-21T10:05:00Z", msg.deletedAtIso)
        assertEquals("2026-05-21T10:02:00Z", msg.editedAtIso)
    }

    @Test fun `isDeleted reflects presence of deletedAt`() {
        assertFalse(emptyDto().toDomain().isDeleted)
        assertTrue(emptyDto().copy(deletedAt = "2026-05-21T10:00:00Z").toDomain().isDeleted)
    }

    @Test fun `isEdited reflects presence of editedAt`() {
        assertFalse(emptyDto().toDomain().isEdited)
        assertTrue(emptyDto().copy(editedAt = "2026-05-21T10:00:00Z").toDomain().isEdited)
    }

    @Test fun `createdAtInstant parses ISO instants`() {
        val msg = emptyDto().copy(createdAt = "2026-05-21T10:00:00Z").toDomain()
        assertEquals("2026-05-21T10:00:00Z", msg.createdAtInstant?.toString())
    }

    @Test fun `createdAtInstant null on missing or malformed ISO`() {
        assertNull(emptyDto().toDomain().createdAtInstant)
        assertNull(emptyDto().copy(createdAt = "not-iso").toDomain().createdAtInstant)
    }
}
