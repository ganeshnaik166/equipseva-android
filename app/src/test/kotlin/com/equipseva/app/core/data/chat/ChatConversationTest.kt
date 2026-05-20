package com.equipseva.app.core.data.chat

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

class ChatConversationTest {

    @Test fun `legacy conversation row with null participants maps to empty list`() {
        val dto = ConversationDto(
            id = "conv-1",
            participantUserIds = null,
        )
        assertTrue(dto.toDomain().participantUserIds.isEmpty())
    }

    @Test fun `counterpartId returns the other participant`() {
        val convo = ChatConversation(
            id = "conv-1",
            participantUserIds = listOf("u1", "u2"),
            relatedEntityType = null,
            relatedEntityId = null,
            lastMessage = null,
            lastMessageAtIso = null,
            createdAtIso = null,
        )
        assertEquals("u2", convo.counterpartId("u1"))
        assertEquals("u1", convo.counterpartId("u2"))
    }

    @Test fun `counterpartId returns null when conversation has no participants`() {
        val convo = ChatConversation(
            id = "conv-1",
            participantUserIds = emptyList(),
            relatedEntityType = null,
            relatedEntityId = null,
            lastMessage = null,
            lastMessageAtIso = null,
            createdAtIso = null,
        )
        assertNull(convo.counterpartId("u1"))
    }

    @Test fun `counterpartId returns null when only self is a participant`() {
        // Self-conversation edge case — RLS shouldn't allow this, but the
        // helper must not falsely surface a counterpart that doesn't exist.
        val convo = ChatConversation(
            id = "conv-1",
            participantUserIds = listOf("u1"),
            relatedEntityType = null,
            relatedEntityId = null,
            lastMessage = null,
            lastMessageAtIso = null,
            createdAtIso = null,
        )
        assertNull(convo.counterpartId("u1"))
    }

    @Test fun `counterpartId on a group conversation picks the first non-self`() {
        // Group conversations don't exist in v1, but the helper still needs
        // a stable answer for support cases that find a malformed row.
        val convo = ChatConversation(
            id = "conv-1",
            participantUserIds = listOf("u1", "u2", "u3"),
            relatedEntityType = null,
            relatedEntityId = null,
            lastMessage = null,
            lastMessageAtIso = null,
            createdAtIso = null,
        )
        assertEquals("u2", convo.counterpartId("u1"))
    }

    @Test fun `lastMessageInstant parses iso or degrades to null`() {
        val convo = ChatConversation(
            id = "conv-1",
            participantUserIds = listOf("u1"),
            relatedEntityType = null,
            relatedEntityId = null,
            lastMessage = "hi",
            lastMessageAtIso = "2026-05-04T09:00:00Z",
            createdAtIso = null,
        )
        assertEquals(Instant.parse("2026-05-04T09:00:00Z"), convo.lastMessageInstant)

        val bad = convo.copy(lastMessageAtIso = "not-a-time")
        assertNull(bad.lastMessageInstant)

        val none = convo.copy(lastMessageAtIso = null)
        assertNull(none.lastMessageInstant)
    }

    @Test fun `domain mapping copies related entity discriminators`() {
        val dto = ConversationDto(
            id = "conv-1",
            participantUserIds = listOf("u1", "u2"),
            relatedEntityType = "repair_job",
            relatedEntityId = "job-9",
            lastMessage = "On the way",
            lastMessageAt = "2026-05-04T09:00:00Z",
            createdAt = "2026-05-04T08:30:00Z",
        )
        val domain = dto.toDomain()
        assertEquals("repair_job", domain.relatedEntityType)
        assertEquals("job-9", domain.relatedEntityId)
        assertEquals("On the way", domain.lastMessage)
        assertEquals(Instant.parse("2026-05-04T09:00:00Z"), domain.lastMessageInstant)
    }
}
