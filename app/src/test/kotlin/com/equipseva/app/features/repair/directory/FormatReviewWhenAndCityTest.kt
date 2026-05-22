package com.equipseva.app.features.repair.directory

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the "when · city" line composer on the engineer-review item.
 * Critical region: the middle-dot separator is U+00B7 (typographic
 * middle dot), not ASCII "·" or "•" / "*". Pin so a refactor that
 * normalised to ASCII surfaces.
 */
class FormatReviewWhenAndCityTest {

    @Test fun `both present joins with middle-dot separator`() {
        assertEquals(
            "3 days ago · Bengaluru",
            formatReviewWhenAndCity("3 days ago", "Bengaluru"),
        )
    }

    @Test fun `null city omits the separator`() {
        assertEquals("3 days ago", formatReviewWhenAndCity("3 days ago", null))
    }

    @Test fun `blank city omits the separator`() {
        // Pin so an empty / whitespace-only city doesn't surface
        // " · " trailing the date.
        assertEquals("3 days ago", formatReviewWhenAndCity("3 days ago", "  "))
        assertEquals("3 days ago", formatReviewWhenAndCity("3 days ago", ""))
    }

    @Test fun `empty whenLabel and present city produces leading separator (defensive)`() {
        // UI always passes a non-empty whenLabel via relativeLabel,
        // but pin the empty-when shape so the helper is total.
        assertEquals(" · Bengaluru", formatReviewWhenAndCity("", "Bengaluru"))
    }

    @Test fun `both empty returns empty string`() {
        assertEquals("", formatReviewWhenAndCity("", null))
        assertEquals("", formatReviewWhenAndCity("", "  "))
    }

    @Test fun `separator is U+00B7 not ASCII (typographic middle dot)`() {
        val out = formatReviewWhenAndCity("3 days ago", "Bengaluru")
        // U+00B7 MIDDLE DOT — not ASCII "·" (same glyph, different
        // codepoint) and not "*" / "•".
        assertEquals(true, out.contains('·'))
        assertEquals(false, out.contains('*'))
        assertEquals(false, out.contains('•'))
    }
}
