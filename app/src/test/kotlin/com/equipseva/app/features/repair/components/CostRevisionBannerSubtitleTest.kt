package com.equipseva.app.features.repair.components

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the cost-revision banner subtitle copy. The rupee amounts go
 * through formatRupees (Indian lakh grouping) and the arrow glyph is
 * U+2192 RIGHTWARDS ARROW, not the ASCII "->" digraph. A regression
 * to ASCII would visually fragment the banner.
 */
class CostRevisionBannerSubtitleTest {

    @Test fun `small amounts render with the unicode arrow`() {
        assertEquals(
            "₹2,500 → ₹3,000. Tap to review.",
            costRevisionBannerSubtitle(2500.0, 3000.0),
        )
    }

    @Test fun `arrow glyph is U+2192 RIGHTWARDS ARROW (not ASCII)`() {
        val text = costRevisionBannerSubtitle(1000.0, 1500.0)
        assertTrue("arrow glyph missing from $text", text.contains('→'))
        // Defensive — pin so a future refactor doesn't normalise to "->".
        assertEquals(-1, text.indexOf("->"))
    }

    @Test fun `lakh amounts use Indian grouping on both sides`() {
        // ₹1,00,000 → ₹1,50,000 (lakh grouping, not Western).
        assertEquals(
            "₹1,00,000 → ₹1,50,000. Tap to review.",
            costRevisionBannerSubtitle(100000.0, 150000.0),
        )
    }

    @Test fun `decreasing revision (revised lt original) still renders straightforwardly`() {
        // The banner doesn't apply a sign — it just shows the
        // before-and-after; the decision sheet shows the signed delta.
        assertEquals(
            "₹5,000 → ₹4,000. Tap to review.",
            costRevisionBannerSubtitle(5000.0, 4000.0),
        )
    }

    @Test fun `equal amounts (no-op revision) still render — caller filters`() {
        // The propose_cost_revision RPC rejects no-ops server-side,
        // but client-side defensive rendering must not crash if a
        // race produces equal values.
        assertEquals(
            "₹2,500 → ₹2,500. Tap to review.",
            costRevisionBannerSubtitle(2500.0, 2500.0),
        )
    }

    @Test fun `tap-to-review call to action is included verbatim`() {
        // The banner is tappable — the trailing "Tap to review." is
        // the visual affordance. Pin so it doesn't drift.
        val text = costRevisionBannerSubtitle(1000.0, 2000.0)
        assertTrue(text.endsWith(". Tap to review."))
    }
}
