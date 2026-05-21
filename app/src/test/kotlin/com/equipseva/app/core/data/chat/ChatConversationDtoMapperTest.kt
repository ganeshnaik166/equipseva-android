package com.equipseva.app.core.data.chat

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins [ConversationDto] → [ChatConversation] mapping + the two derived
 * helpers (`lastMessageInstant`, `counterpartId`). The inbox row sorts
 * by `lastMessageInstant` so a regression in the parse fallback would
 * misorder the entire conversation list.
 */
class ChatConversationDtoMapperTest {

    private fun emptyDto(id: String = "c1") = ConversationDto(id = id)

    @Test fun `all-null dto maps to safe defaults with empty participants`() {
        val conv = emptyDto().toDomain()
        assertEquals("c1", conv.id)
        // The @Immutable assumption depends on a non-null list — the
        // mapper folds null → [] so Compose can skip rows safely.
        assertTrue(conv.participantUserIds.isEmpty())
        assertNull(conv.relatedEntityType)
        assertNull(conv.relatedEntityId)
        assertNull(conv.lastMessage)
        assertNull(conv.lastMessageAtIso)
        assertNull(conv.createdAtIso)
        assertEquals(0, conv.unreadCount)
    }

    @Test fun `populated dto fields round-trip`() {
        val conv = emptyDto().copy(
            participantUserIds = listOf("u1", "u2"),
            relatedEntityType = "repair_job",
            relatedEntityId = "j1",
            lastMessage = "On my way",
            lastMessageAt = "2026-05-21T10:00:00Z",
            createdAt = "2026-05-20T10:00:00Z",
        ).toDomain()

        assertEquals(listOf("u1", "u2"), conv.participantUserIds)
        assertEquals("repair_job", conv.relatedEntityType)
        assertEquals("j1", conv.relatedEntityId)
        assertEquals("On my way", conv.lastMessage)
        assertEquals("2026-05-21T10:00:00Z", conv.lastMessageAtIso)
        assertEquals("2026-05-20T10:00:00Z", conv.createdAtIso)
    }

    @Test fun `lastMessageInstant parses ISO and falls back to null on malformed`() {
        val ok = emptyDto().copy(lastMessageAt = "2026-05-21T10:00:00Z").toDomain()
        assertEquals("2026-05-21T10:00:00Z", ok.lastMessageInstant?.toString())

        val bad = emptyDto().copy(lastMessageAt = "not-iso").toDomain()
        assertNull(bad.lastMessageInstant)
    }

    @Test fun `counterpartId returns the first participant that is not self`() {
        val conv = emptyDto().copy(participantUserIds = listOf("u1", "u2")).toDomain()
        assertEquals("u2", conv.counterpartId("u1"))
        assertEquals("u1", conv.counterpartId("u2"))
    }

    @Test fun `counterpartId returns null when only self is a participant`() {
        // Edge: realtime can briefly publish a row with a single
        // participant during the soft-delete reaper transition.
        val conv = emptyDto().copy(participantUserIds = listOf("u1")).toDomain()
        assertNull(conv.counterpartId("u1"))
    }

    @Test fun `counterpartId returns null when participant list is empty`() {
        assertNull(emptyDto().toDomain().counterpartId("u1"))
    }
}
