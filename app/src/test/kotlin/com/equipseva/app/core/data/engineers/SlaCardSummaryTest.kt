package com.equipseva.app.core.data.engineers

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins for the r1397 engineer SLA-card helpers: on-time banding, dispute-rate
 * banding, and the nullable hours formatter.
 */
class SlaCardSummaryTest {

    // ---- onTimeBand ---------------------------------------------------

    @Test fun `on-time at or above 95 is excellent`() {
        assertEquals("excellent", onTimeBand(95.0))
        assertEquals("excellent", onTimeBand(100.0))
    }

    @Test fun `on-time in the 85 to 95 range is good`() {
        assertEquals("good", onTimeBand(85.0))
        assertEquals("good", onTimeBand(94.999))
    }

    @Test fun `on-time below 85 needs attention`() {
        assertEquals("attention", onTimeBand(84.99))
        assertEquals("attention", onTimeBand(0.0))
    }

    // ---- disputeRateBand ----------------------------------------------

    @Test fun `exactly zero disputes is clean`() {
        assertEquals("clean", disputeRateBand(0.0))
    }

    @Test fun `below 5 percent is low`() {
        assertEquals("low", disputeRateBand(0.1))
        assertEquals("low", disputeRateBand(4.999))
    }

    @Test fun `5 percent or more is elevated`() {
        assertEquals("elevated", disputeRateBand(5.0))
        assertEquals("elevated", disputeRateBand(20.0))
    }

    // ---- formatSlaHours -----------------------------------------------

    @Test fun `hours drop the decimal when whole, keep one otherwise`() {
        assertEquals("6 h", formatSlaHours(6.0))
        assertEquals("6.5 h", formatSlaHours(6.5))
        assertEquals("0 h", formatSlaHours(0.0))
    }

    @Test fun `null or negative hours is em dash`() {
        assertEquals("—", formatSlaHours(null))
        assertEquals("—", formatSlaHours(-2.0))
    }
}
