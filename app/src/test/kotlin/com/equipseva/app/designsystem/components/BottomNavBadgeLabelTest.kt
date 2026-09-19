package com.equipseva.app.designsystem.components

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the bottom-nav unread badge text.
 *
 * Critical regression target: the badge used to render the raw count, so a
 * hospital returning to a busy inbox (three-digit unread) overflowed the
 * 18 dp circle over a 22 dp icon and collided with the neighbouring tab.
 *
 * The cap is at 99, not 9 — two digits still fit the pill, and "9+" would
 * throw away information the user can act on.
 */
class BottomNavBadgeLabelTest {

    @Test fun `single digit renders verbatim`() {
        assertEquals("1", bottomNavBadgeLabel(1))
        assertEquals("9", bottomNavBadgeLabel(9))
    }

    @Test fun `two digits render verbatim`() {
        assertEquals("10", bottomNavBadgeLabel(10))
        assertEquals("99", bottomNavBadgeLabel(99))
    }

    @Test fun `99 is the last verbatim value and 100 is the first capped one`() {
        // Boundary pin — an off-by-one here shows up as a clipped "100".
        assertEquals("99", bottomNavBadgeLabel(99))
        assertEquals("99+", bottomNavBadgeLabel(100))
    }

    @Test fun `large counts cap at 99 plus`() {
        assertEquals("99+", bottomNavBadgeLabel(120))
        assertEquals("99+", bottomNavBadgeLabel(4321))
        assertEquals("99+", bottomNavBadgeLabel(Int.MAX_VALUE))
    }

    @Test fun `no label is ever wider than three glyphs`() {
        // The pill's width budget. Sampled across the whole range plus the
        // extremes, so a future "1.2k" style formatter has to revisit the
        // badge geometry deliberately.
        val samples = listOf(0, 1, 9, 10, 50, 99, 100, 1000, Int.MAX_VALUE)
        samples.forEach { count ->
            assertTrue(
                "count $count produced ${bottomNavBadgeLabel(count)}",
                bottomNavBadgeLabel(count).length <= 3,
            )
        }
    }
}
