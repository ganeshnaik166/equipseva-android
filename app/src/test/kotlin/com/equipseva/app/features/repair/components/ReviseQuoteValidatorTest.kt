package com.equipseva.app.features.repair.components

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the revise-quote sheet's local pre-validate gate. Server-side
 * propose_cost_revision RPC is the source of truth, but the client
 * gate drives the Submit button's enabled state so users get instant
 * feedback. Two boundary regions:
 *
 *   1) Revised must STRICTLY exceed the current contracted amount —
 *      equal-to is not enough (no-op revisions are explicitly
 *      blocked).
 *   2) Reason length is gated to [50, 500] chars inclusive. The
 *      counter chip on the sheet's UI is driven off this same range,
 *      so a regression here mis-tints the counter too.
 */
class ReviseQuoteValidatorTest {

    @Test fun `happy path parses amount and validates both fields`() {
        val v = validateReviseQuote(
            amountText = "3500",
            reason = "Additional scope discovered after teardown — needs new probe " +
                "head and recalibration kit, ~3h total labour.",
            currentContractedRupees = 2500.0,
        )
        assertEquals(3500.0, v.parsedAmount)
        assertTrue(v.amountValid)
        assertTrue(v.reasonValid)
        assertTrue(v.canSubmit)
    }

    @Test fun `non-numeric amount yields null parsedAmount and invalid amount`() {
        val v = validateReviseQuote("abc", longEnoughReason(), 2500.0)
        assertNull(v.parsedAmount)
        assertFalse(v.amountValid)
        assertFalse(v.canSubmit)
    }

    @Test fun `amount equal to contracted is rejected (strict gt)`() {
        val v = validateReviseQuote("2500", longEnoughReason(), 2500.0)
        assertEquals(2500.0, v.parsedAmount)
        assertFalse(v.amountValid)
        assertFalse(v.canSubmit)
    }

    @Test fun `amount below contracted is rejected`() {
        val v = validateReviseQuote("1500", longEnoughReason(), 2500.0)
        assertFalse(v.amountValid)
    }

    @Test fun `amount accepts decimal values`() {
        val v = validateReviseQuote("2500.50", longEnoughReason(), 2500.0)
        assertEquals(2500.50, v.parsedAmount!!, 0.001)
        assertTrue(v.amountValid)
    }

    @Test fun `whitespace-padded amount still parses`() {
        val v = validateReviseQuote("  3500  ", longEnoughReason(), 2500.0)
        assertEquals(3500.0, v.parsedAmount)
        assertTrue(v.amountValid)
    }

    // ---- reason length gates ----

    @Test fun `reason at exactly 50 chars (min boundary) passes`() {
        val reason = "x".repeat(50)
        val v = validateReviseQuote("3500", reason, 2500.0)
        assertTrue(v.reasonValid)
        assertTrue(v.canSubmit)
    }

    @Test fun `reason at 49 chars fails (one below min)`() {
        val reason = "x".repeat(49)
        val v = validateReviseQuote("3500", reason, 2500.0)
        assertFalse(v.reasonValid)
        assertFalse(v.canSubmit)
    }

    @Test fun `reason at exactly 500 chars (max boundary) passes`() {
        val reason = "x".repeat(500)
        val v = validateReviseQuote("3500", reason, 2500.0)
        assertTrue(v.reasonValid)
    }

    @Test fun `reason at 501 chars fails (one above max)`() {
        val reason = "x".repeat(501)
        val v = validateReviseQuote("3500", reason, 2500.0)
        assertFalse(v.reasonValid)
    }

    @Test fun `reason length is measured AFTER trim — leading-trailing spaces don't count`() {
        // Pin the trim-before-measure semantics; otherwise a user
        // could pad with spaces to bypass the min-length gate.
        val reason = "   " + "x".repeat(40) + "   "
        val v = validateReviseQuote("3500", reason, 2500.0)
        assertFalse(v.reasonValid)
    }

    @Test fun `blank reason fails the min-length gate`() {
        val v = validateReviseQuote("3500", "   ", 2500.0)
        assertFalse(v.reasonValid)
    }

    // ---- canSubmit ----

    @Test fun `canSubmit false when only amount valid`() {
        val v = validateReviseQuote("3500", "too short", 2500.0)
        assertTrue(v.amountValid)
        assertFalse(v.reasonValid)
        assertFalse(v.canSubmit)
    }

    @Test fun `canSubmit false when only reason valid`() {
        val v = validateReviseQuote("1500", longEnoughReason(), 2500.0)
        assertFalse(v.amountValid)
        assertTrue(v.reasonValid)
        assertFalse(v.canSubmit)
    }

    @Test fun `constants are 50 and 500 (server-side contract)`() {
        assertEquals(50, REASON_MIN)
        assertEquals(500, REASON_MAX)
    }

    // helper
    private fun longEnoughReason(): String =
        "x".repeat(50)
}
