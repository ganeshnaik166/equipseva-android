package com.equipseva.app.designsystem.components

import androidx.compose.ui.unit.dp
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * UI-02 minimum size roles; SharedActionLayoutTest verifies real growable
 * geometry. The old 44dp pins are intentionally superseded by the approved
 * 48dp secondary / 52dp primary contract and are not accessibility evidence alone.
 */
class EsBtnHeightTest {

    @Test fun `small variant has a 48dp secondary action floor`() {
        assertEquals(48.dp, heightFor(EsBtnSize.Sm))
    }

    @Test fun `medium variant has a 52dp primary action floor`() {
        assertEquals(52.dp, heightFor(EsBtnSize.Md))
    }

    @Test fun `large variant is 52dp`() {
        assertEquals(52.dp, heightFor(EsBtnSize.Lg))
    }

    @Test fun `every size meets the 48dp accessibility floor`() {
        EsBtnSize.entries.forEach { size ->
            assertTrue(
                "$size below 48dp touch-target floor",
                heightFor(size).value >= 48f,
            )
        }
    }

    @Test fun `large never has a smaller minimum than medium`() {
        assertTrue(heightFor(EsBtnSize.Lg).value >= heightFor(EsBtnSize.Md).value)
    }
}
