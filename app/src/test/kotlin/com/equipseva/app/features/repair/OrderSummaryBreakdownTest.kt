package com.equipseva.app.features.repair

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the r1499 GST-INCLUSIVE order-summary breakdown. The old sheet ADDED
 * 18% on top of the bid ("Total ₹2,950 / Pay ₹2,950" on a ₹2,500 bid) while
 * the server charges the bid verbatim and the round449 invoice reverses the
 * tax out of it (taxable = round(gross / 1.18, 2)). Verified live on
 * RPR-00040: the promised total exceeded the actual Razorpay charge by 18%.
 * These pins keep the sheet footing to the real charge + the real invoice.
 */
class OrderSummaryBreakdownTest {

    @Test fun `total always equals the bid (the actual charge), never bid plus 18 pct`() {
        assertEquals(2500.0, orderSummaryBreakdown(2500.0).total, 0.0)
        assertEquals(1000.0, orderSummaryBreakdown(1000.0).total, 0.0)
        assertEquals(123.45, orderSummaryBreakdown(123.45).total, 0.0)
    }

    @Test fun `taxable value mirrors the round449 invoice reversal`() {
        // round(2500 / 1.18, 2) = 2118.64 — must match the GST invoice the
        // hospital downloads after completion.
        assertEquals(2118.64, orderSummaryBreakdown(2500.0).taxableValue, 0.0)
        // round(1180 / 1.18, 2) = 1000.00 (exact case)
        assertEquals(1000.0, orderSummaryBreakdown(1180.0).taxableValue, 0.0)
    }

    @Test fun `gst included is the remainder, and the rows foot to the total`() {
        val b = orderSummaryBreakdown(2500.0)
        assertEquals(381.36, b.gstIncluded, 0.0)
        assertEquals(b.total, b.taxableValue + b.gstIncluded, 0.005)
    }

    @Test fun `exact-multiple bid splits cleanly`() {
        val b = orderSummaryBreakdown(1180.0)
        assertEquals(180.0, b.gstIncluded, 0.0)
        assertEquals(1180.0, b.total, 0.0)
    }
}
