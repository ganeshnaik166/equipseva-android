package com.equipseva.app.core.data.chat

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * The three chat entry points (repair_job, rfq_bid, direct) all funnel into
 * the same Postgrest insert against `chat_conversations`. The wire-format
 * constants and direct's null-entityId quirk live in [buildConversationInsert]
 * + the RELATED_TYPE_* constants. Pinning them here catches a copy-paste
 * regression that would surface as RLS-deny (mismatched related_entity_type)
 * or as an extra direct conversation row (null vs empty entity id drift).
 */
class ConversationInsertBuilderTest {

    @Test fun `RELATED_TYPE constants match the values RLS policies filter on`() {
        // RLS policies on chat_conversations key off these exact strings; a
        // rename here without a matching migration breaks every chat entry.
        assertEquals("repair_job", RELATED_TYPE_REPAIR_JOB)
        assertEquals("rfq_bid", RELATED_TYPE_RFQ_BID)
        assertEquals("direct", RELATED_TYPE_DIRECT)
    }

    @Test fun `repair-job payload carries the job id as related_entity_id`() {
        val dto = buildConversationInsert(
            RELATED_TYPE_REPAIR_JOB,
            entityId = "job-42",
            participantUserIds = listOf("hospital-1", "engineer-7"),
        )
        assertEquals("repair_job", dto.relatedEntityType)
        assertEquals("job-42", dto.relatedEntityId)
        assertEquals(listOf("hospital-1", "engineer-7"), dto.participantUserIds)
    }

    @Test fun `rfq-bid payload carries the bid id as related_entity_id`() {
        val dto = buildConversationInsert(
            RELATED_TYPE_RFQ_BID,
            entityId = "bid-9",
            participantUserIds = listOf("hospital-1", "vendor-3"),
        )
        assertEquals("rfq_bid", dto.relatedEntityType)
        assertEquals("bid-9", dto.relatedEntityId)
        assertEquals(listOf("hospital-1", "vendor-3"), dto.participantUserIds)
    }

    @Test fun `direct payload intentionally has a null related_entity_id`() {
        // Direct chats are user-to-user with no anchored entity. A regression
        // that stamped "" or "direct" into related_entity_id would silently
        // break the dedup query, which filters on type=direct alone and
        // ignores entity_id.
        val dto = buildConversationInsert(
            RELATED_TYPE_DIRECT,
            entityId = null,
            participantUserIds = listOf("user-a", "user-b"),
        )
        assertEquals("direct", dto.relatedEntityType)
        assertNull(dto.relatedEntityId)
        assertEquals(listOf("user-a", "user-b"), dto.participantUserIds)
    }

    @Test fun `participant order is preserved verbatim into the insert payload`() {
        // We never sort participant ids on the way in — server-side dedup
        // (and matchesDirectParticipants on the read path) is order-insensitive,
        // but the row stores whatever the caller passed.
        val dto = buildConversationInsert(
            RELATED_TYPE_DIRECT,
            entityId = null,
            participantUserIds = listOf("z-user", "a-user"),
        )
        assertEquals(listOf("z-user", "a-user"), dto.participantUserIds)
    }
}
