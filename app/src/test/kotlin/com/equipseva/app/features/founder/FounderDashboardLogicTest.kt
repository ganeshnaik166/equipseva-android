package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the Indian-style grouping used by the founder dashboard hero card
 * ("₹1,23,456"). The bucket boundaries (3 / 5 / 7-digit) are easy to flip
 * by accident when refactoring; pin every branch + the null / negative /
 * fractional inputs so the founder never sees a US-style 123,456,789.
 */
class FounderDashboardLogicTest {

    @Test fun `null and zero render as 0`() {
        // Null guard exists so callers can pass `state.stats?.todayPayments`
        // straight in during loading without an `?: 0.0` at each site.
        assertEquals("0", founderFormatRupeesShort(null))
        assertEquals("0", founderFormatRupeesShort(0.0))
    }

    @Test fun `up to three digits returns the digits verbatim`() {
        // No grouping needed below 1,000 — this is the fast-path for tiny
        // platforms (single test orders, dev seed data).
        assertEquals("7", founderFormatRupeesShort(7.0))
        assertEquals("42", founderFormatRupeesShort(42.0))
        assertEquals("999", founderFormatRupeesShort(999.0))
    }

    @Test fun `four-digit input gets a single comma after the tail-3 split`() {
        // 4-digit edge: head ("1") is short enough that the while loop
        // never executes, so the StringBuilder just becomes "1,234".
        assertEquals("1,234", founderFormatRupeesShort(1234.0))
    }

    @Test fun `five-digit input uses Indian grouping with a 2-digit head group`() {
        assertEquals("12,345", founderFormatRupeesShort(12345.0))
    }

    @Test fun `six and seven digit inputs split into lakh and crore tens groups`() {
        // The actual money path: founder dashboard summing all orders today.
        assertEquals("1,23,456", founderFormatRupeesShort(123456.0))
        assertEquals("12,34,567", founderFormatRupeesShort(1234567.0))
    }

    @Test fun `crore-scale input keeps the 2-digit groups all the way up`() {
        // 1,23,45,67,890 — verifies the while-loop trims `rem` 2 chars
        // at a time without dropping the leading digit.
        assertEquals("1,23,45,67,890", founderFormatRupeesShort(1234567890.0))
    }

    @Test fun `fractional input truncates toward zero before grouping`() {
        // `.toLong()` truncates, so 1500.99 must render 1,500 — not 1,501.
        assertEquals("1,500", founderFormatRupeesShort(1500.99))
        assertEquals("1,500", founderFormatRupeesShort(1500.01))
    }

    @Test fun `negative input passes the minus sign through grouping`() {
        // Refunds aren't surfaced on the founder hero today but the helper
        // shouldn't blow up on a Razorpay net-negative day either.
        assertEquals("-1,234", founderFormatRupeesShort(-1234.0))
    }
}
