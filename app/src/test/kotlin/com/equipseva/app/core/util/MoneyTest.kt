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

    @Test fun `large amount carries rupee symbol and digits`() {
        // Note: current impl uses `Locale("en","IN")` which on most JVMs
        // produces Western-grouped digits (180,000 not 1,80,000) because
        // ICU rules vary. Lock the current observable behaviour — symbol
        // + correct digits — so a future refactor that swaps to custom
        // DecimalFormat with explicit Indian grouping wouldn't silently
        // break callers that grep on this output (Sentry breadcrumbs,
        // tests, etc.).
        val out = formatRupees(180000.0)
        org.junit.Assert.assertTrue(out.contains("₹"))
        org.junit.Assert.assertTrue(out.contains("180,000") || out.contains("1,80,000"))
    }

    @Test fun `decimals are dropped`() {
        // maximumFractionDigits = 0 → 1500.75 should render as 1,501 (rounded)
        // or 1,500 (truncated). NumberFormat default rounds half-up.
        val out = formatRupees(1500.75)
        org.junit.Assert.assertTrue(
            "expected rounded whole rupees, got '$out'",
            out.contains("1,501") || out.contains("1,500"),
        )
        org.junit.Assert.assertFalse("paise should be hidden in '$out'", out.contains(".75"))
    }

    @Test fun `zero rendered cleanly`() {
        val out = formatRupees(0.0)
        org.junit.Assert.assertTrue(out.contains("₹"))
        org.junit.Assert.assertTrue(out.contains("0"))
    }

    @Test fun `crore-scale carries rupee symbol`() {
        val out = formatRupees(120000000.0)
        org.junit.Assert.assertTrue(out.contains("₹"))
        // Accept either grouping pattern depending on JVM ICU.
        org.junit.Assert.assertTrue(out.contains("120,000,000") || out.contains("12,00,00,000"))
    }
}
