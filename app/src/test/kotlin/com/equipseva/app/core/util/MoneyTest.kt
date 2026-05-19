package com.equipseva.app.core.util

import org.junit.Assert.assertEquals
import org.junit.Test

class MoneyTest {

    // Round 397 — formatRupees is on every money-bearing surface
    // (Payments GMV header, Earnings hero, AMC list, dispute card,
    // engineer self-rank, hospital booking row). Locale must produce
    // Indian-grouping (1,80,000 not 180,000) and no paise.

    @Test fun `whole rupees rendered with rupee symbol`() {
        // Trim spaces because some JVMs insert U+00A0 between symbol and
        // digits; equality on full string is too brittle. Test for the
        // digit grouping + symbol presence.
        val out = formatRupees(1800.0)
        org.junit.Assert.assertTrue(out.contains("₹"))
        org.junit.Assert.assertTrue(out.contains("1,800"))
    }

    @Test fun `large amount uses Indian lakh grouping`() {
        // Round 408 — tighten the assertion that round 397 had to leave
        // loose. After r398's explicit `##,##,##0` DecimalFormat the
        // output is guaranteed Indian-grouped regardless of JVM ICU.
        // ₹180000 must read "₹1,80,000" — anything else (including the
        // Western "180,000") is a regression and customers would see
        // the wrong number on every money-bearing surface.
        val out = formatRupees(180000.0)
        org.junit.Assert.assertTrue(out.contains("₹"))
        org.junit.Assert.assertTrue(
            "expected Indian-grouped 1,80,000 in '$out'",
            out.contains("1,80,000"),
        )
        org.junit.Assert.assertFalse(
            "Western grouping '180,000' must not appear in '$out'",
            out.contains("180,000"),
        )
    }

    @Test fun `decimals are rounded to nearest whole rupee`() {
        // Round 409 — tighten the last remaining `A || B` assertion. After
        // r408 the impl uses `kotlin.math.round` deterministically:
        //   round-to-nearest, ties to even (banker's rounding).
        // 1500.75 is unambiguously 1501; 1500.25 is unambiguously 1500.
        org.junit.Assert.assertEquals("₹1,501", formatRupees(1500.75))
        org.junit.Assert.assertEquals("₹1,500", formatRupees(1500.25))
    }

    @Test fun `half-rupee ties round to even (banker's rounding)`() {
        // Round 409 — pin the tie-breaker behavior so a future refactor
        // to half-up wouldn't slip through. 1500.5 → 1500 (even neighbor),
        // 1501.5 → 1502 (even neighbor). This matches kotlin.math.round's
        // documented contract.
        org.junit.Assert.assertEquals("₹1,500", formatRupees(1500.5))
        org.junit.Assert.assertEquals("₹1,502", formatRupees(1501.5))
    }

    @Test fun `zero rendered cleanly`() {
        val out = formatRupees(0.0)
        org.junit.Assert.assertTrue(out.contains("₹"))
        org.junit.Assert.assertTrue(out.contains("0"))
    }

    @Test fun `crore-scale uses Indian crore grouping`() {
        // Round 408 — same tightening: post-r398 we own the grouping
        // explicitly. ₹12,00,00,000 (twelve crore) is the canonical
        // Indian rendering; "120,000,000" would be a regression to the
        // platform Locale path that r398 deliberately abandoned.
        val out = formatRupees(120000000.0)
        org.junit.Assert.assertTrue(out.contains("₹"))
        org.junit.Assert.assertTrue(
            "expected Indian-grouped 12,00,00,000 in '$out'",
            out.contains("12,00,00,000"),
        )
        org.junit.Assert.assertFalse(
            "Western grouping '120,000,000' must not appear in '$out'",
            out.contains("120,000,000"),
        )
    }

    @Test fun `lakh boundary renders with first comma after three digits`() {
        // Round 408 — verify the exact boundary: 99,999 stays 3-digit
        // grouped; 1,00,000 introduces the lakh grouping. This pins the
        // ##,##,##0 pattern: rightmost group is 3 digits, then 2 each.
        org.junit.Assert.assertEquals("₹99,999", formatRupees(99999.0))
        org.junit.Assert.assertEquals("₹1,00,000", formatRupees(100000.0))
    }
}
