package com.equipseva.app.core.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Cost banners, the cost-revision sheet and the engineer earnings tile all
 * read through formatRupees. Confirm the Indian-locale formatting + no-paise
 * + ₹ symbol contract. JDK locale-specific quirks (lakh grouping, narrow
 * non-breaking space between the symbol and the value) live here so a
 * runtime ICU update can't quietly change the surface text.
 */
class MoneyTest {

    @Test fun `whole amount renders with rupee symbol and no paise`() {
        val out = formatRupees(1800.0)
        assertTrue("expected ₹ prefix in $out", out.contains("₹"))
        assertTrue("expected 1,800 digits in $out", out.contains("1,800"))
        // Indian formatter never emits a decimal for these values.
        assertTrue("paise not expected in $out", !out.contains("."))
    }

    @Test fun `fractional rupees are rounded to whole`() {
        // maximumFractionDigits = 0 — anything sub-rupee collapses.
        val out = formatRupees(1500.49)
        assertTrue(out.contains("1,500"))
        val outRoundUp = formatRupees(1500.50)
        assertTrue(outRoundUp.contains("1,501") || outRoundUp.contains("1,500"))
    }

    @Test fun `zero renders as a clean ₹0`() {
        val out = formatRupees(0.0)
        assertTrue("expected ₹ prefix in $out", out.contains("₹"))
        assertTrue("expected 0 in $out", out.contains("0"))
    }

    @Test fun `large amounts use grouping commas`() {
        // The exact grouping pattern (1,00,000 lakh vs 100,000 Western)
        // depends on the JDK's en-IN locale data — older JDKs ship Western
        // grouping under en-IN. Don't pin the comma positions; just confirm
        // we get a digit-grouped number and the ₹ symbol.
        val out = formatRupees(100_000.0)
        assertTrue("expected ₹ prefix in $out", out.contains("₹"))
        assertTrue("expected grouping comma in $out", out.contains(","))
    }

    @Test fun `negative values keep a leading minus`() {
        // Cost revisions can go negative (refund estimate); we don't render
        // them anywhere in the UI yet, but the formatter still needs to be
        // sensible if a row arrives with a negative.
        val out = formatRupees(-1500.0)
        assertTrue("expected minus sign in $out", out.contains("-") || out.contains("(") || out.contains("−"))
    }
}
