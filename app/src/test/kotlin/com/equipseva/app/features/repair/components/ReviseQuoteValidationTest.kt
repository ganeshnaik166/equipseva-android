package com.equipseva.app.features.repair.components

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The Revise-Quote sheet pre-validates locally so the engineer gets
 * fast feedback on Submit availability before the server's
 * propose_cost_revision check rejects them. The same SQL enforces
 * revised > contracted and reason length 50..500; the unit tests pin
 * the boundary values 50 / 500 + the "submitting" lockout so a future
 * refactor doesn't silently widen or tighten the rules.
 */
class ReviseQuoteValidationTest {

    @Test fun `reason min and max constants match the server-side contract`() {
        // The SQL function propose_cost_revision uses 50..500 — drift
        // here would let the client send a payload the server rejects,
        // breaking the "fast feedback" property the sheet is meant to
        // provide.
        assertEquals(50, REVISE_QUOTE_REASON_MIN)
        assertEquals(500, REVISE_QUOTE_REASON_MAX)
    }

    @Test fun `blank amount yields null parsed and disables submit`() {
        val v = validateReviseQuote(
            amountText = "",
            reason = "x".repeat(60),
            currentContractedRupees = 1000.0,
            submitting = false,
        )
        assertNull(v.parsedAmount)
        assertFalse(v.amountValid)
        // Empty (not just <=) — don't scold the user before they type.
        assertFalse(v.amountTooLow)
        assertFalse(v.canSubmit)
    }

    @Test fun `unparseable amount text yields null parsed`() {
        // The Composable's onChange filters to digits + dot, but a saved-
        // state restore could feed back garbage; verify the parser is
        // defensive.
        val v = validateReviseQuote(
            amountText = "abc",
            reason = "x".repeat(60),
            currentContractedRupees = 1000.0,
            submitting = false,
        )
        assertNull(v.parsedAmount)
        assertFalse(v.amountValid)
        assertFalse(v.amountTooLow)
    }

    @Test fun `whitespace around amount still parses`() {
        // Saveable restore can re-pad; trim must happen before parse so
        // the validation snapshot matches what the user sees.
        val v = validateReviseQuote(
            amountText = "  1500  ",
            reason = "x".repeat(60),
            currentContractedRupees = 1000.0,
            submitting = false,
        )
        assertEquals(1500.0, v.parsedAmount)
        assertTrue(v.amountValid)
    }

    @Test fun `amount equal to contracted is too low not valid`() {
        // Boundary — server requires strictly greater. Equality is the
        // most likely engineer mistake (re-typing the same number).
        val v = validateReviseQuote(
            amountText = "1000",
            reason = "x".repeat(60),
            currentContractedRupees = 1000.0,
            submitting = false,
        )
        assertFalse(v.amountValid)
        assertTrue(v.amountTooLow)
        assertFalse(v.canSubmit)
    }

    @Test fun `amount below contracted is too low`() {
        val v = validateReviseQuote(
            amountText = "500",
            reason = "x".repeat(60),
            currentContractedRupees = 1000.0,
            submitting = false,
        )
        assertFalse(v.amountValid)
        assertTrue(v.amountTooLow)
    }

    @Test fun `amount one rupee above contracted is valid`() {
        // The strict-greater rule — pin the cheapest valid bump.
        val v = validateReviseQuote(
            amountText = "1001",
            reason = "x".repeat(60),
            currentContractedRupees = 1000.0,
            submitting = false,
        )
        assertTrue(v.amountValid)
        assertFalse(v.amountTooLow)
    }

    @Test fun `reason length 49 fails the min boundary`() {
        val v = validateReviseQuote(
            amountText = "1500",
            reason = "x".repeat(49),
            currentContractedRupees = 1000.0,
            submitting = false,
        )
        assertFalse(v.reasonValid)
        assertEquals(49, v.reasonLen)
        assertFalse(v.canSubmit)
    }

    @Test fun `reason length 50 hits the min boundary exactly`() {
        // Inclusive lower bound — must match the server's >= 50 check.
        val v = validateReviseQuote(
            amountText = "1500",
            reason = "x".repeat(50),
            currentContractedRupees = 1000.0,
            submitting = false,
        )
        assertTrue(v.reasonValid)
        assertEquals(50, v.reasonLen)
        assertTrue(v.canSubmit)
    }

    @Test fun `reason length 500 hits the max boundary exactly`() {
        // Inclusive upper bound — server allows up to 500 chars.
        val v = validateReviseQuote(
            amountText = "1500",
            reason = "x".repeat(500),
            currentContractedRupees = 1000.0,
            submitting = false,
        )
        assertTrue(v.reasonValid)
        assertEquals(500, v.reasonLen)
        assertTrue(v.canSubmit)
    }

    @Test fun `reason length 501 fails the max boundary`() {
        // The Composable lets the user type past the limit (max + 5
        // slack) so they can see the over-count hint; validation must
        // reject anything > 500.
        val v = validateReviseQuote(
            amountText = "1500",
            reason = "x".repeat(501),
            currentContractedRupees = 1000.0,
            submitting = false,
        )
        assertFalse(v.reasonValid)
        assertEquals(501, v.reasonLen)
        assertFalse(v.canSubmit)
    }

    @Test fun `reason length is measured after trim`() {
        // Leading/trailing whitespace mustn't pad a short reason past
        // the min. The reasonTrimmed field also feeds the submit
        // callback so the server sees the same string.
        val padded = "   " + "x".repeat(49) + "   "
        val v = validateReviseQuote(
            amountText = "1500",
            reason = padded,
            currentContractedRupees = 1000.0,
            submitting = false,
        )
        assertEquals(49, v.reasonLen)
        assertEquals("x".repeat(49), v.reasonTrimmed)
        assertFalse(v.reasonValid)
    }

    @Test fun `submitting flag blocks canSubmit even when both fields valid`() {
        // While propose_cost_revision is in flight the sheet keeps the
        // primary CTA disabled to prevent a double-submit; both repos
        // would 409 anyway but the UX should never let it happen.
        val v = validateReviseQuote(
            amountText = "1500",
            reason = "x".repeat(60),
            currentContractedRupees = 1000.0,
            submitting = true,
        )
        assertTrue(v.amountValid)
        assertTrue(v.reasonValid)
        assertFalse(v.canSubmit)
    }

    @Test fun `canSubmit false when reason is empty regardless of amount`() {
        val v = validateReviseQuote(
            amountText = "1500",
            reason = "",
            currentContractedRupees = 1000.0,
            submitting = false,
        )
        assertTrue(v.amountValid)
        assertFalse(v.reasonValid)
        assertEquals(0, v.reasonLen)
        assertFalse(v.canSubmit)
    }

    @Test fun `canSubmit true when all preconditions satisfied`() {
        val v = validateReviseQuote(
            amountText = "2500",
            reason = "Found additional damage to the vapouriser seat seal " +
                "and a second leak at the inlet manifold; both need " +
                "replacement parts.",
            currentContractedRupees = 1000.0,
            submitting = false,
        )
        assertTrue(v.amountValid)
        assertTrue(v.reasonValid)
        assertTrue(v.canSubmit)
    }
}
