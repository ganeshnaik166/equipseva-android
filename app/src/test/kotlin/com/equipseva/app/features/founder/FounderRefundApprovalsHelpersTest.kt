package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins for the r1423 founder refund-approval helpers. */
class FounderRefundApprovalsHelpersTest {

    @Test fun `reject reason needs at least five trimmed chars`() {
        assertEquals(true, isValidRejectReason("Duplicate request"))
        assertEquals(true, isValidRejectReason("abcde"))
        assertEquals(false, isValidRejectReason("abcd"))
        assertEquals(false, isValidRejectReason("   x   "))
        assertEquals(false, isValidRejectReason(""))
    }

    @Test fun `source label de-snakes and falls back`() {
        assertEquals("Amc contract", refundSourceLabel("amc_contract"))
        assertEquals("Repair job", refundSourceLabel("repair_job"))
        assertEquals("Refund", refundSourceLabel(""))
    }
}
