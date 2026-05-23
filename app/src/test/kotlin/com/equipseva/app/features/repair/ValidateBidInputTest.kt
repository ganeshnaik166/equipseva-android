package com.equipseva.app.features.repair

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins the bid-submission input validator. Two range gates:
 *
 *   * amount: [1, 10_000_000] rupees inclusive. The 1cr cap surfaces
 *     a misplaced-decimal-point typo as a toast instead of letting
 *     it through to the server's 422 path.
 *   * eta: optional; when present, must be in [1, 720] hours
 *     (30 days). Null means "no ETA quoted" and passes through.
 *
 * The error copy is user-visible (rendered in a snackbar) and has
 * been reviewed by product — pin so a refactor that changes wording
 * surfaces in review.
 */
class ValidateBidInputTest {

    @Test fun `happy path returns null`() {
        assertNull(validateBidInput(amountRupees = 2500.0, etaHours = 4))
    }

    @Test fun `null eta is allowed (no ETA quoted)`() {
        assertNull(validateBidInput(amountRupees = 2500.0, etaHours = null))
    }

    // ---- amount ----

    @Test fun `amount below floor (zero) is rejected`() {
        assertEquals(
            "Enter a bid between ₹1 and ₹1 crore",
            validateBidInput(amountRupees = 0.0, etaHours = 4),
        )
    }

    @Test fun `amount below floor (0_5) is rejected`() {
        assertEquals(
            "Enter a bid between ₹1 and ₹1 crore",
            validateBidInput(amountRupees = 0.5, etaHours = 4),
        )
    }

    @Test fun `amount at minimum (1 rupee) passes`() {
        assertNull(validateBidInput(amountRupees = 1.0, etaHours = 4))
    }

    @Test fun `amount at maximum (1 crore exact) passes`() {
        assertNull(validateBidInput(amountRupees = 10_000_000.0, etaHours = 4))
    }

    @Test fun `amount above 1 crore is rejected`() {
        assertEquals(
            "Enter a bid between ₹1 and ₹1 crore",
            validateBidInput(amountRupees = 10_000_001.0, etaHours = 4),
        )
    }

    @Test fun `negative amount is rejected`() {
        assertEquals(
            "Enter a bid between ₹1 and ₹1 crore",
            validateBidInput(amountRupees = -100.0, etaHours = 4),
        )
    }

    @Test fun `non-finite amount (NaN, Infinity) is rejected`() {
        assertEquals(
            "Enter a bid between ₹1 and ₹1 crore",
            validateBidInput(amountRupees = Double.NaN, etaHours = 4),
        )
        assertEquals(
            "Enter a bid between ₹1 and ₹1 crore",
            validateBidInput(amountRupees = Double.POSITIVE_INFINITY, etaHours = 4),
        )
        assertEquals(
            "Enter a bid between ₹1 and ₹1 crore",
            validateBidInput(amountRupees = Double.NEGATIVE_INFINITY, etaHours = 4),
        )
    }

    // ---- eta ----

    @Test fun `eta below floor (zero) is rejected`() {
        // 0 hours = "immediate" but the server treats it as "no ETA
        // quoted" which is the null path. Force the engineer to pick
        // a real number.
        val err = validateBidInput(amountRupees = 2500.0, etaHours = 0)
        assertEquals("ETA must be 1–720 hours", err)
    }

    @Test fun `eta at minimum (1 hour) passes`() {
        assertNull(validateBidInput(amountRupees = 2500.0, etaHours = 1))
    }

    @Test fun `eta at maximum (720 hours, 30 days) passes`() {
        assertNull(validateBidInput(amountRupees = 2500.0, etaHours = 720))
    }

    @Test fun `eta above 720 hours (31 days) is rejected`() {
        val err = validateBidInput(amountRupees = 2500.0, etaHours = 721)
        assertEquals("ETA must be 1–720 hours", err)
    }

    @Test fun `negative eta is rejected`() {
        val err = validateBidInput(amountRupees = 2500.0, etaHours = -5)
        assertEquals("ETA must be 1–720 hours", err)
    }

    // ---- error precedence ----

    @Test fun `amount error wins over eta error when both invalid`() {
        // The amount gate runs first — fix the amount, then the
        // eta error (if still invalid) surfaces on the next attempt.
        val err = validateBidInput(amountRupees = 0.0, etaHours = 999)
        assertEquals("Enter a bid between ₹1 and ₹1 crore", err)
    }
}
