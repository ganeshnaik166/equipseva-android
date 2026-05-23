package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CashFlagHistorySubtitleTest {

    @Test fun `non-empty list reads count responses last 365d`() {
        assertEquals(
            "5 responses · last 365d",
            cashFlagHistorySubtitle(5),
        )
    }

    @Test fun `empty list returns null`() {
        assertNull(cashFlagHistorySubtitle(0))
    }

    @Test fun `365d rolling window preserved (distinct from 30d queues)`() {
        // Critical pin — distinct from the 30d windows on escrow
        // resolved + AMC expiring queues. Cash-flag history queries
        // the full year because suspensions stay relevant.
        val out = cashFlagHistorySubtitle(1)
        assertTrue(out!!.endsWith("last 365d"))
        assertEquals(false, out.contains("30d"))
    }

    @Test fun `responses noun distinct from flags`() {
        // Pin — "responses" (survey replies) NOT "flags" (the
        // server-side cash_flags rows). A flag is what triggers
        // suspension; a response is just a reply.
        val out = cashFlagHistorySubtitle(3)
        assertTrue(out!!.contains("responses"))
        assertEquals(false, out.contains("flags"))
    }

    @Test fun `middle dot is U+00B7`() {
        val out = cashFlagHistorySubtitle(1)
        assertTrue(out!!.contains(" · "))
    }

    @Test fun `1 row reads 1 responses plural (documented behaviour)`() {
        // Plural-blind. A future singular fix should be deliberate.
        assertEquals(
            "1 responses · last 365d",
            cashFlagHistorySubtitle(1),
        )
    }
}
