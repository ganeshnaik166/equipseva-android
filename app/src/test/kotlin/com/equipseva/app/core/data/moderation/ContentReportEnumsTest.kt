package com.equipseva.app.core.data.moderation

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the wire `key` strings for the two content-reporting enums.
 * The server-side `content_reports` table has CHECK constraints on
 * both `target_type` and `reason` that match these keys verbatim — a
 * rename here (without a coordinated DB migration) would surface as
 * a 23514 violation on every reported row.
 *
 * Also pins the user-visible `displayName` copy on
 * [ContentReportReason] since it ships into the report sheet's
 * radio-list directly.
 */
class ContentReportEnumsTest {

    @Test fun `ContentReportTarget keys match the DB CHECK constraint`() {
        assertEquals("chat_message", ContentReportTarget.ChatMessage.key)
        assertEquals("repair_job", ContentReportTarget.RepairJob.key)
    }

    @Test fun `ContentReportTarget exposes exactly two client-emittable values`() {
        // Server-side CHECK accepts more (e.g. engineer profile, AMC
        // visit) but the client doesn't surface buttons for those —
        // pin to two until that ships.
        assertEquals(2, ContentReportTarget.entries.size)
    }

    @Test fun `ContentReportReason keys match the DB CHECK constraint`() {
        assertEquals("spam", ContentReportReason.Spam.key)
        assertEquals("scam", ContentReportReason.Scam.key)
        assertEquals("abuse", ContentReportReason.Abuse.key)
        assertEquals("harassment", ContentReportReason.Harassment.key)
        assertEquals("inappropriate", ContentReportReason.Inappropriate.key)
        assertEquals("illegal", ContentReportReason.Illegal.key)
        assertEquals("other", ContentReportReason.Other.key)
    }

    @Test fun `ContentReportReason display copy matches the pinned product strings`() {
        assertEquals("Spam or scam", ContentReportReason.Spam.displayName)
        assertEquals("Fraud / scam", ContentReportReason.Scam.displayName)
        assertEquals("Abusive language", ContentReportReason.Abuse.displayName)
        assertEquals("Harassment", ContentReportReason.Harassment.displayName)
        assertEquals("Inappropriate content", ContentReportReason.Inappropriate.displayName)
        assertEquals("Illegal activity", ContentReportReason.Illegal.displayName)
        assertEquals("Something else", ContentReportReason.Other.displayName)
    }

    @Test fun `ContentReportReason keys are all distinct`() {
        val keys = ContentReportReason.entries.map { it.key }
        assertEquals(keys.size, keys.toSet().size)
    }

    @Test fun `ContentReportReason keys are lowercase ascii (server-side enum format)`() {
        ContentReportReason.entries.forEach { reason ->
            assertEquals(
                "${reason.name} key should be lowercase",
                reason.key,
                reason.key.lowercase(),
            )
            assertTrue(
                "${reason.name} key has whitespace",
                reason.key.none { it.isWhitespace() },
            )
        }
    }
}
