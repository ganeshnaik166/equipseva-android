package com.equipseva.app.core.data.chat

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

/**
 * Chat surfaces three "presentation" booleans (`isDeleted`, `isEdited`,
 * `isRead`) derived from columns that can be absent on legacy rows. Pin
 * each fall-through so the bubble UI never has to add its own null guards.
 */
class ChatMessageTest {

    @Test fun `legacy MessageDto with null fields maps to safe defaults`() {
        val dto = MessageDto(
            id = "m1",
            conversationId = "conv-1",
            senderUserId = "u1",
            message = null,
            attachments = null,
            isRead = null,
            createdAt = null,
            deletedAt = null,
            editedAt = null,
        )
        val domain = dto.toDomain()
        assertEquals("", domain.message)
        assertTrue(domain.attachments.isEmpty())
        assertFalse(domain.isRead)
        assertFalse(domain.isDeleted)
        assertFalse(domain.isEdited)
        assertNull(domain.createdAtInstant)
    }

    @Test fun `MessageDto with attachments and read flag round-trip`() {
        val dto = MessageDto(
            id = "m2",
            conversationId = "conv-1",
            senderUserId = "u1",
            message = "see attached",
            attachments = listOf("https://x/a.jpg", "https://x/b.pdf"),
            isRead = true,
            createdAt = "2026-05-04T09:00:00Z",
        )
        val domain = dto.toDomain()
        assertEquals("see attached", domain.message)
        assertEquals(2, domain.attachments.size)
        assertTrue(domain.isRead)
        assertEquals(Instant.parse("2026-05-04T09:00:00Z"), domain.createdAtInstant)
    }

    @Test fun `deletedAt iso populates isDeleted`() {
        val dto = MessageDto(
            id = "m3",
            conversationId = "conv-1",
            senderUserId = "u1",
            message = "oops",
            deletedAt = "2026-05-04T09:05:00Z",
        )
        val domain = dto.toDomain()
        assertTrue(domain.isDeleted)
        // Bubble UI hides the body, but the field is still carried through —
        // assert the wire data we depend on is intact.
        assertEquals("oops", domain.message)
    }

    @Test fun `editedAt iso populates isEdited`() {
        val dto = MessageDto(
            id = "m4",
            conversationId = "conv-1",
            senderUserId = "u1",
            message = "fixed",
            editedAt = "2026-05-04T09:10:00Z",
        )
        assertTrue(dto.toDomain().isEdited)
    }

    @Test fun `malformed createdAt degrades to null`() {
        val dto = MessageDto(
            id = "m5",
            conversationId = "conv-1",
            senderUserId = "u1",
            message = "x",
            createdAt = "not-a-date",
        )
        assertNull(dto.toDomain().createdAtInstant)
    }

    @Test fun `createdAtInstant recomputes from the iso field`() {
        val first = ChatMessage(
            id = "m6",
            conversationId = "conv-1",
            senderUserId = "u1",
            message = "x",
            attachments = emptyList(),
            isRead = false,
            createdAtIso = "2026-05-04T09:00:00Z",
        )
        val edited = first.copy(createdAtIso = "2026-05-04T10:00:00Z")
        assertEquals(Instant.parse("2026-05-04T10:00:00Z"), edited.createdAtInstant)
    }
}
