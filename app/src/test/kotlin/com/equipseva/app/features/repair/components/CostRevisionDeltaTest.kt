package com.equipseva.app.features.repair.components

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * `costRevisionDelta` summarises the absolute + percentage gap between the
 * engineer's original quote and the proposed revision. Useful for any
 * future telemetry / sheet copy that wants "+25% (₹500)" style framing.
 * The zero-original guard is the most load-bearing branch: a stale row
 * with original=0 must not produce Infinity or NaN-flavoured output.
 */
class CostRevisionDeltaTest {

    @Test fun `pure increase produces positive percent and isIncrease true`() {
        // 1000 → 1500: delta 500, 50% up.
        val d = costRevisionDelta(original = 1000.0, revised = 1500.0)
        assertEquals(500.0, d.absoluteRupees, 0.0)
        assertEquals(50, d.percentChange)
        assertTrue(d.isIncrease)
    }

    @Test fun `pure decrease produces positive absolute but negative percent`() {
        // 2000 → 1500: delta 500 (always positive — magnitude), percent
        // -25 (signed — direction). Splitting absolute vs signed lets
        // the caller pick the framing without re-deriving sign.
        val d = costRevisionDelta(original = 2000.0, revised = 1500.0)
        assertEquals(500.0, d.absoluteRupees, 0.0)
        assertEquals(-25, d.percentChange)
        assertFalse(d.isIncrease)
    }

    @Test fun `zero delta gives zero across the board and isIncrease false`() {
        // Engineer "revises" to the same number (typo / no-op). Percent
        // is exactly 0, magnitude 0; isIncrease must be strictly
        // greater-than (not gte) so a no-op isn't framed as a hike.
        val d = costRevisionDelta(original = 1000.0, revised = 1000.0)
        assertEquals(0.0, d.absoluteRupees, 0.0)
        assertEquals(0, d.percentChange)
        assertFalse(d.isIncrease)
    }

    @Test fun `zero original returns null percent and skips divide-by-zero`() {
        // The guarded branch — original of 0 would otherwise blow up as
        // Infinity. Pin null so callers can fall back to "+₹X" without
        // a percent.
        val d = costRevisionDelta(original = 0.0, revised = 1500.0)
        assertNull(d.percentChange)
        assertEquals(1500.0, d.absoluteRupees, 0.0)
        assertTrue(d.isIncrease)
    }

    @Test fun `zero original and zero revised still null percent`() {
        // Pathological but safe — 0 / 0 must not produce NaN.
        val d = costRevisionDelta(original = 0.0, revised = 0.0)
        assertNull(d.percentChange)
        assertEquals(0.0, d.absoluteRupees, 0.0)
        assertFalse(d.isIncrease)
    }

    @Test fun `percent change rounds half away from zero like Math round`() {
        // 1000 → 1125 = 12.5% — Math.round(12.5) = 13 (HALF_UP).
        val d = costRevisionDelta(original = 1000.0, revised = 1125.0)
        assertEquals(13, d.percentChange)
    }

    @Test fun `percent change rounds down when below half`() {
        // 1000 → 1124 = 12.4% → rounds to 12.
        val d = costRevisionDelta(original = 1000.0, revised = 1124.0)
        assertEquals(12, d.percentChange)
    }

    @Test fun `large delta with awkward original still rounds to whole percent`() {
        // 3333 → 4444 ≈ 33.33% → rounds to 33; pin so a future refactor
        // to BigDecimal doesn't shift the rounding direction.
        val d = costRevisionDelta(original = 3333.0, revised = 4444.0)
        assertEquals(33, d.percentChange)
    }

    @Test fun `tiny one-rupee bump on a large original still yields zero percent`() {
        // 100_000 → 100_001: 0.001% → rounds to 0. The hospital should
        // still see the delta numerically (1.0 rupee) — the percent is
        // an aid, not a gate.
        val d = costRevisionDelta(original = 100_000.0, revised = 100_001.0)
        assertEquals(0, d.percentChange)
        assertEquals(1.0, d.absoluteRupees, 0.0)
        assertTrue(d.isIncrease)
    }
}
