package com.equipseva.app.designsystem.components

import androidx.compose.ui.unit.dp
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the per-size button height contract. The 44dp Md default is
 * the accessibility-minimum touch-target size (Material 3 + iOS HIG
 * agree on 44pt/44dp). A regression that shrunk Md below 44dp would
 * silently degrade tap accessibility on every primary CTA — keep it
 * frozen.
 */
class EsBtnHeightTest {

    @Test fun `small variant is 36dp`() {
        assertEquals(36.dp, heightFor(EsBtnSize.Sm))
    }

    @Test fun `medium variant is 44dp (accessibility floor)`() {
        // 44dp is the floor for an accessible touch target; pin so a
        // future "compact" tweak doesn't slip past review.
        assertEquals(44.dp, heightFor(EsBtnSize.Md))
    }

    @Test fun `large variant is 52dp`() {
        assertEquals(52.dp, heightFor(EsBtnSize.Lg))
    }

    @Test fun `every size produces a unique height (no duplicates)`() {
        val heights = EsBtnSize.entries.map(::heightFor)
        assertEquals(heights.size, heights.toSet().size)
    }

    @Test fun `sizes are strictly monotonically increasing`() {
        // Sm < Md < Lg — pin so a future tweak that flips two doesn't
        // silently confuse the visual hierarchy.
        assertEquals(true, heightFor(EsBtnSize.Sm).value < heightFor(EsBtnSize.Md).value)
        assertEquals(true, heightFor(EsBtnSize.Md).value < heightFor(EsBtnSize.Lg).value)
    }
}
