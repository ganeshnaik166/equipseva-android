package com.equipseva.app.features.home.dashboards

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import java.util.Locale

/**
 * Dashboard stat tiles use a compact ₹ formatter distinct from the
 * verbose `core.util.formatRupees` (which renders "₹1,200" with full
 * grouping). This one collapses large values to k / L / Cr suffixes so
 * "Today's earnings" doesn't break the three-up StatRow layout when an
 * engineer crosses ₹1 crore lifetime.
 *
 * Pin the bucket boundaries (1k, 1L = 1,00,000, 1Cr = 1,00,00,000) and
 * the negative-collapses-to-zero contract — earnings tiles show stale
 * cached data sometimes and a "-₹4.5k" tile would be confusing UX.
 */
class DashboardCommonFormatRupeesTest {

    // Pin locale so "%.1f" uses a period not a comma on non-en-US dev boxes.
    // `formatRupees` calls `String.format` without an explicit Locale, so it
    // picks up the JVM default — we override it here for test determinism.
    private var prev: Locale = Locale.getDefault()

    @Before fun setUp() {
        prev = Locale.getDefault()
        Locale.setDefault(Locale.US)
    }

    @After fun tearDown() {
        Locale.setDefault(prev)
    }

    @Test fun `zero renders as flat rupee zero`() {
        // Onboarding state — engineer has no earnings yet. Must show "₹0"
        // (not "₹0.0k") so the tile reads cleanly.
        assertEquals("₹0", formatRupees(0.0))
    }

    @Test fun `negative values collapse to flat rupee zero`() {
        // Defensive — cached earnings sometimes returns a stale negative
        // delta. Don't render "-₹4.5k" in the stat tile.
        assertEquals("₹0", formatRupees(-1.0))
        assertEquals("₹0", formatRupees(-9999.0))
    }

    @Test fun `sub-thousand values render as whole rupees`() {
        // Below ₹1,000 → no suffix, just the integer rupee value.
        assertEquals("₹999", formatRupees(999.0))
        assertEquals("₹1", formatRupees(1.0))
        assertEquals("₹500", formatRupees(500.49))
    }

    @Test fun `thousands bucket renders with k suffix to one decimal`() {
        // 1,000 ≤ value < 1,00,000 → "₹X.Xk".
        assertEquals("₹1.0k", formatRupees(1_000.0))
        assertEquals("₹24.5k", formatRupees(24_500.0))
        assertEquals("₹99.9k", formatRupees(99_900.0))
    }

    @Test fun `lakhs bucket renders with L suffix to one decimal`() {
        // 1,00,000 ≤ value < 1,00,00,000 → "₹X.XL". This is the
        // characteristic Indian compact-currency shape.
        assertEquals("₹1.0L", formatRupees(1_00_000.0))
        assertEquals("₹1.2L", formatRupees(1_20_000.0))
        assertEquals("₹99.9L", formatRupees(99_90_000.0))
    }

    @Test fun `crores bucket renders with Cr suffix to one decimal`() {
        // ≥ 1,00,00,000 → "₹X.XCr". Pin so the tile doesn't overflow
        // into scientific notation on a partnership-tier supplier.
        assertEquals("₹1.0Cr", formatRupees(1_00_00_000.0))
        assertEquals("₹3.4Cr", formatRupees(3_40_00_000.0))
        assertEquals("₹12.5Cr", formatRupees(12_50_00_000.0))
    }

    @Test fun `boundary at 999 stays in plain bucket`() {
        // Just-under-thousand uses plain rupee form, no k suffix.
        assertEquals("₹999", formatRupees(999.0))
        // Just-over-thousand flips to "k".
        assertEquals("₹1.0k", formatRupees(1_000.0))
    }

    @Test fun `boundary at 1 lakh flips from k to L`() {
        // 99_999 still in k bucket, 1_00_000 in L bucket.
        assertEquals("₹100.0k", formatRupees(99_999.0))
        assertEquals("₹1.0L", formatRupees(1_00_000.0))
    }

    @Test fun `boundary at 1 crore flips from L to Cr`() {
        // 99_99_999 still in L bucket, 1_00_00_000 in Cr bucket.
        assertEquals("₹100.0L", formatRupees(99_99_999.0))
        assertEquals("₹1.0Cr", formatRupees(1_00_00_000.0))
    }
}
