package com.equipseva.app.designsystem.theme

import androidx.compose.ui.graphics.Color
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the WCAG AA contrast of the token pairs the app actually ships for
 * small body text.
 *
 * These pairings shipped below the 4.5:1 floor and were invisible to review
 * because they look fine on a bright desk monitor:
 *
 *  - SevaInk400 captions measured 3.95:1 on white and 3.70:1 on PaperDefault,
 *    used for 10-12 sp timestamps and stat sublines.
 *  - The home hero's white-at-65%-alpha stat labels measured 3.61:1 over
 *    SevaGreen700, and the 75%-alpha greeting 4.27:1.
 *
 * None of them qualifies for the large-text exemption (AA allows 3:1 only at
 * 18 pt / 14 pt bold and up), so the replacements below are the contract.
 */
class TokenContrastTest {

    private val heroGreen = SevaGreen700

    private fun assertMeetsAaBodyText(label: String, fg: Color, bg: Color) {
        val ratio = contrastRatio(fg, bg)
        assertTrue("$label measured %.2f:1, needs 4.5:1".format(ratio), ratio >= 4.5)
    }

    @Test fun `SevaInk400 fails AA on both light surfaces so it is not a caption colour`() {
        // The regression target itself: if a future token edit lifts
        // SevaInk400 above 4.5:1 this test tells us the captions may move
        // back. Until then, treat it as decorative only (icon tints).
        assertTrue(contrastRatio(SevaInk400, Color.White) < 4.5)
        assertTrue(contrastRatio(SevaInk400, PaperDefault) < 4.5)
    }

    @Test fun `SevaInk500 is the caption colour on white`() {
        assertMeetsAaBodyText("SevaInk500 on white", SevaInk500, Color.White)
    }

    @Test fun `SevaInk500 is the caption colour on PaperDefault`() {
        assertMeetsAaBodyText("SevaInk500 on PaperDefault", SevaInk500, PaperDefault)
    }

    @Test fun `SevaInk500 is the caption colour on the green-50 unread row`() {
        // The notifications inbox tints unread rows SevaGreen50, so the
        // timestamp sits on that, not on white.
        assertMeetsAaBodyText("SevaInk500 on SevaGreen50", SevaInk500, SevaGreen50)
    }

    @Test fun `hero label alpha of 0-65 fails and 0-85 passes on brand green`() {
        assertTrue(contrastRatio(Color.White.copy(alpha = 0.65f), heroGreen) < 4.5)
        assertMeetsAaBodyText(
            "white at 0.85 on SevaGreen700",
            Color.White.copy(alpha = 0.85f),
            heroGreen,
        )
    }

    @Test fun `hero greeting alpha of 0-75 fails and 0-85 passes on brand green`() {
        assertTrue(contrastRatio(Color.White.copy(alpha = 0.75f), heroGreen) < 4.5)
        assertMeetsAaBodyText(
            "white at 0.85 on SevaGreen700",
            Color.White.copy(alpha = 0.85f),
            heroGreen,
        )
    }

    @Test fun `contrastRatio is symmetric and self-comparison is 1`() {
        // Sanity on the helper itself — the ratio is defined on luminance
        // ordering, not argument order, and an unreadable same-on-same pair
        // must read as 1:1 rather than infinity.
        val a = contrastRatio(SevaInk900, Color.White)
        val b = contrastRatio(Color.White, SevaInk900)
        assertTrue(kotlin.math.abs(a - b) < 0.0001)
        assertTrue(kotlin.math.abs(contrastRatio(SevaInk900, SevaInk900) - 1.0) < 0.0001)
    }

    @Test fun `opaque white on black is the maximum 21 to 1`() {
        val ratio = contrastRatio(Color.White, Color.Black)
        assertTrue("expected ~21:1, got %.2f".format(ratio), ratio > 20.9 && ratio < 21.1)
    }
}
