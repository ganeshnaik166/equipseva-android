package com.equipseva.app.features.repair.components

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the cost-revision delta-text formatter shown on the hospital
 * decision sheet ("+₹500 (+10%)").
 *
 * Two regions worth pinning:
 *   1) The minus sign for negative deltas is the U+2212 MINUS SIGN
 *      `−`, not the ASCII hyphen `-`. The pair (+/−) reads correctly
 *      next to each other; a regression to `-` would look wrong next
 *      to the `+` for positive deltas.
 *   2) The pct chip only renders when |pct| >= 0.5 — sub-half-percent
 *      rounding deltas would otherwise render as "0%" which is
 *      misleading. Pin the boundary.
 */
class CostRevisionDeltaTextTest {

    @Test fun `positive delta with significant pct renders + sign and pct`() {
        assertEquals("+₹500 (+10%)", costRevisionDeltaText(delta = 500.0, pct = 10.0))
    }

    @Test fun `negative delta uses U+2212 MINUS SIGN (not ASCII hyphen)`() {
        // Pin so a future autoformat doesn't normalise to "-".
        val out = costRevisionDeltaText(delta = -300.0, pct = -8.0)
        assertEquals("−₹300 (−8%)", out)
        // Belt-and-braces — explicit code point check.
        assertEquals('−', out.first())
    }

    @Test fun `zero delta renders the plus sign (delta gte 0)`() {
        // The sign gate is `delta >= 0` — pin so zero doesn't read
        // as a negative.
        assertEquals("+₹0", costRevisionDeltaText(delta = 0.0, pct = 0.0))
    }

    @Test fun `tiny pct below half-percent is omitted from the suffix`() {
        // A 0.4% pct should not render — would round to "(0%)".
        assertEquals("+₹500", costRevisionDeltaText(delta = 500.0, pct = 0.4))
        assertEquals("−₹500", costRevisionDeltaText(delta = -500.0, pct = -0.4))
    }

    @Test fun `pct at exactly half-percent renders (boundary inclusive)`() {
        // |pct| >= 0.5 — the boundary value should produce a chip.
        // "%.0f" rounds 0.5 up to "1" on standard JDK rounding so the
        // chip reads "(+1%)". Pin so a refactor that flips to ".1f"
        // or banker's rounding is intentional.
        assertEquals("+₹100 (+1%)", costRevisionDeltaText(delta = 100.0, pct = 0.5))
    }

    @Test fun `large pct rounds to nearest whole number`() {
        // %.0f → integer formatting; pin so "27.6%" reads as "(+28%)".
        assertEquals("+₹1,500 (+28%)", costRevisionDeltaText(delta = 1500.0, pct = 27.6))
    }

    @Test fun `negative delta shows pct without double-negating`() {
        // The pct text uses kotlin.math.abs(pct) — a negative pct
        // should NOT render as "(--N%)". Pin so the abs() doesn't
        // get accidentally dropped.
        val out = costRevisionDeltaText(delta = -250.0, pct = -5.0)
        assertEquals("−₹250 (−5%)", out)
    }

    @Test fun `rupee amount uses Indian grouping via formatRupees`() {
        // Defensive integration check — delegating to formatRupees
        // means the lakh grouping ("1,00,000" not "100,000") is
        // preserved on a large delta.
        assertEquals("+₹1,00,000 (+50%)", costRevisionDeltaText(delta = 100000.0, pct = 50.0))
    }
}
