package com.equipseva.app.designsystem

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the dp → [AdaptiveWidth] bucketing. The boundaries are
 * load-bearing: maxContentWidth (and every wide-screen layout
 * branch downstream) toggles based on which bucket the device
 * lands in. A regression at the boundary would either cap content
 * width on a phone (Compact mis-classified as Medium) or let it
 * sprawl on a tablet (Medium mis-classified as Compact).
 *
 * Boundaries:
 *   <600 → Compact (phones)
 *   600..839 → Medium (small tablets, foldables)
 *   ≥840 → Expanded (large tablets, desktop, ChromeOS landscape)
 */
class AdaptiveWidthTest {

    @Test fun `narrow phone widths are Compact`() {
        assertEquals(AdaptiveWidth.Compact, adaptiveWidthForDp(320))
        assertEquals(AdaptiveWidth.Compact, adaptiveWidthForDp(411))
        assertEquals(AdaptiveWidth.Compact, adaptiveWidthForDp(599))
    }

    @Test fun `600dp boundary flips to Medium (inclusive)`() {
        // The check is `widthDp < 600` so 600 is Medium, 599 is
        // Compact. Pin so a future inclusive-vs-exclusive flip is
        // intentional.
        assertEquals(AdaptiveWidth.Compact, adaptiveWidthForDp(599))
        assertEquals(AdaptiveWidth.Medium, adaptiveWidthForDp(600))
    }

    @Test fun `medium tablet widths are Medium`() {
        assertEquals(AdaptiveWidth.Medium, adaptiveWidthForDp(600))
        assertEquals(AdaptiveWidth.Medium, adaptiveWidthForDp(720))
        assertEquals(AdaptiveWidth.Medium, adaptiveWidthForDp(839))
    }

    @Test fun `840dp boundary flips to Expanded (inclusive)`() {
        // `widthDp < 840` for Medium; 840 is Expanded.
        assertEquals(AdaptiveWidth.Medium, adaptiveWidthForDp(839))
        assertEquals(AdaptiveWidth.Expanded, adaptiveWidthForDp(840))
    }

    @Test fun `large tablet and desktop widths are Expanded`() {
        assertEquals(AdaptiveWidth.Expanded, adaptiveWidthForDp(900))
        assertEquals(AdaptiveWidth.Expanded, adaptiveWidthForDp(1200))
        assertEquals(AdaptiveWidth.Expanded, adaptiveWidthForDp(1920))
    }

    @Test fun `zero or negative dp folds to Compact (defensive)`() {
        // Defensive — a malformed configuration shouldn't crash the
        // layout. Compact is the safest fallback.
        assertEquals(AdaptiveWidth.Compact, adaptiveWidthForDp(0))
        assertEquals(AdaptiveWidth.Compact, adaptiveWidthForDp(-1))
    }

    @Test fun `ContentMaxWidth is 840dp (matches Medium-Expanded boundary)`() {
        // Pin so the cap stays aligned with the Expanded boundary —
        // a refactor that bumped one without the other would either
        // leave Expanded layouts uncapped or apply the cap before
        // the bucket flipped.
        assertEquals(840, ContentMaxWidth.value.toInt())
    }

    @Test fun `three buckets total`() {
        assertEquals(3, AdaptiveWidth.entries.size)
    }
}
