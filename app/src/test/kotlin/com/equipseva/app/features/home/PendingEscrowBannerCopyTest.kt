package com.equipseva.app.features.home

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the r1515 pending-escrow Home banner copy: names the job + exact
 * amount, "+N more" only when several stall, and the subtitle explains the
 * engineer is BLOCKED (the stakes), not just that a bill is unpaid.
 */
class PendingEscrowBannerCopyTest {

    @Test fun `single pending escrow names the job and amount`() {
        val (title, subtitle) = pendingEscrowBannerCopy("RPR-00040", 2500.0, totalCount = 1)
        assertEquals("Complete payment for RPR-00040 — ₹2,500", title)
        assertTrue(subtitle.contains("engineer can't start", ignoreCase = true))
    }

    @Test fun `multiple pending escrows append the extra count`() {
        val (title, _) = pendingEscrowBannerCopy("RPR-00040", 2500.0, totalCount = 3)
        assertTrue("got: $title", title.endsWith("· +2 more"))
    }

    @Test fun `missing job number falls back gracefully`() {
        val (title, _) = pendingEscrowBannerCopy(null, 1000.0, totalCount = 1)
        assertTrue(title.contains("your repair job"))
        val (title2, _) = pendingEscrowBannerCopy("  ", 1000.0, totalCount = 1)
        assertTrue(title2.contains("your repair job"))
    }

    @Test fun `amount uses Indian grouping`() {
        val (title, _) = pendingEscrowBannerCopy("RPR-00041", 100000.0, totalCount = 1)
        assertTrue("got: $title", title.contains("₹1,00,000"))
    }
}
