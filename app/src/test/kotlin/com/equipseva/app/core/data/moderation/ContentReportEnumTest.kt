package com.equipseva.app.core.data.moderation

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The `key` values on ContentReportTarget + ContentReportReason are wired
 * directly into the `target_type` and `reason` CHECK constraints on
 * `public.content_reports`. A rename here causes every report INSERT to
 * fail server-side with a constraint violation, and the only signal the
 * user gets is a generic "couldn't submit" toast. Pin the contract.
 */
class ContentReportEnumTest {

    @Test fun `target keys match the SQL CHECK constraint`() {
        assertEquals("chat_message", ContentReportTarget.ChatMessage.key)
        assertEquals("part_listing", ContentReportTarget.PartListing.key)
        assertEquals("repair_job", ContentReportTarget.RepairJob.key)
        assertEquals("rfq", ContentReportTarget.Rfq.key)
        assertEquals("profile", ContentReportTarget.Profile.key)
    }

    @Test fun `target keys are all snake_case and lowercase`() {
        // The CHECK constraint matches these as literals, so an accidental
        // camelCase / SCREAMING_CASE would silently break submission.
        ContentReportTarget.entries.forEach { target ->
            assertEquals(target.key.lowercase(), target.key)
            assertTrue(
                "expected snake_case for ${target.name} (got ${target.key})",
                target.key.matches(Regex("^[a-z][a-z0-9_]*$")),
            )
        }
    }

    @Test fun `reason keys match the SQL CHECK constraint`() {
        assertEquals("spam", ContentReportReason.Spam.key)
        assertEquals("scam", ContentReportReason.Scam.key)
        assertEquals("abuse", ContentReportReason.Abuse.key)
        assertEquals("harassment", ContentReportReason.Harassment.key)
        assertEquals("inappropriate", ContentReportReason.Inappropriate.key)
        assertEquals("illegal", ContentReportReason.Illegal.key)
        assertEquals("other", ContentReportReason.Other.key)
    }

    @Test fun `every reason has a non-blank display name for the picker sheet`() {
        ContentReportReason.entries.forEach { reason ->
            assertNotNull(reason.displayName)
            assertTrue(
                "blank displayName for ${reason.name}",
                reason.displayName.isNotBlank(),
            )
        }
    }

    @Test fun `reason and target sets are stable - covers the documented 5 + 7 catalog`() {
        // Belt-and-braces: a removal here would silently strip a picker
        // option in the bottom sheet (the report-flow surface fans this
        // enum out into rows automatically). Verifying the cardinality
        // catches accidental commits.
        assertEquals(5, ContentReportTarget.entries.size)
        assertEquals(7, ContentReportReason.entries.size)
    }
}
