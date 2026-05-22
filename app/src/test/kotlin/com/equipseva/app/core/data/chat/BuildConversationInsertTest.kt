package com.equipseva.app.core.data.chat

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins the two `ConversationInsertDto` composers used to create chat
 * conversations. The `related_entity_type` literals are wire-frozen
 * ("repair_job" / "direct") because the same strings drive the
 * de-dupe queries — a refactor that renamed either would silently
 * orphan existing conversations + let new duplicates slip past.
 */
class BuildConversationInsertTest {

    @Test fun `repair-job conversation carries the related_entity link`() {
        val dto = buildRepairJobConversationInsert(
            participantUserIds = listOf("u-1", "u-2"),
            jobId = "j-1",
        )
        assertEquals(listOf("u-1", "u-2"), dto.participantUserIds)
        assertEquals("repair_job", dto.relatedEntityType)
        assertEquals("j-1", dto.relatedEntityId)
    }

    @Test fun `repair_job entity_type literal is exactly the wire string (de-dupe key)`() {
        // Pin so a refactor that introduced a constant doesn't drift.
        val dto = buildRepairJobConversationInsert(listOf("u-1", "u-2"), "j-1")
        assertEquals("repair_job", dto.relatedEntityType)
    }

    @Test fun `direct conversation has direct entity_type and null entity_id`() {
        val dto = buildDirectConversationInsert("u-1", "u-2")
        assertEquals(listOf("u-1", "u-2"), dto.participantUserIds)
        assertEquals("direct", dto.relatedEntityType)
        assertNull(dto.relatedEntityId)
    }

    @Test fun `direct entity_type literal is exactly the wire string`() {
        val dto = buildDirectConversationInsert("u-1", "u-2")
        assertEquals("direct", dto.relatedEntityType)
    }

    @Test fun `direct conversation preserves participant order (caller order is wire order)`() {
        // The de-dupe predicate uses set equality so order doesn't
        // matter for matching, but the insert preserves caller order
        // so the schema's participant_user_ids array matches what
        // the UI sees in subsequent reads.
        val dto = buildDirectConversationInsert("u-2", "u-1")
        assertEquals(listOf("u-2", "u-1"), dto.participantUserIds)
    }

    @Test fun `repair-job conversation tolerates a 2-element participant list`() {
        // Caller is required to pass exactly two (the require() gate
        // upstream enforces); pin so the composer faithfully forwards.
        val dto = buildRepairJobConversationInsert(listOf("u-buyer", "u-eng"), "j-99")
        assertEquals(2, dto.participantUserIds.size)
    }
}
