package com.equipseva.app.designsystem.components

import androidx.compose.ui.unit.dp
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the per-size button height contract.
 *
 * Round 461: Sm was bumped from 36dp → 44dp to honor WCAG / Material 3
 * touch-target minimum on every CTA, including the compact variant.
 * After that change, Sm and Md collapse to the same 44dp floor —
 * differentiation is via padding + font size, not height. Lg is the
 * only variant taller than the floor.
 */
class EsBtnHeightTest {

    @Test fun `small variant meets accessibility floor (44dp)`() {
        assertEquals(44.dp, heightFor(EsBtnSize.Sm))
    }

    @Test fun `medium variant is 44dp (accessibility floor)`() {
        assertEquals(44.dp, heightFor(EsBtnSize.Md))
    }

    @Test fun `large variant is 52dp`() {
        assertEquals(52.dp, heightFor(EsBtnSize.Lg))
    }

    @Test fun `every size meets the 44dp accessibility floor`() {
        EsBtnSize.entries.forEach { size ->
            assertTrue(
                "$size below 44dp WCAG / Material touch-target floor",
                heightFor(size).value >= 44f,
            )
        }
    }

    @Test fun `Lg is strictly taller than Md`() {
        // After round 461, Sm == Md == 44dp (the a11y floor); only
        // Lg is taller. Pin that single ordering invariant so a
        // future tweak doesn't shrink Lg below Md.
        assertTrue(heightFor(EsBtnSize.Lg).value > heightFor(EsBtnSize.Md).value)
    }
}
