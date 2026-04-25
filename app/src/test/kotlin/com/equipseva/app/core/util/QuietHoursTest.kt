package com.equipseva.app.core.util

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class QuietHoursTest {

    @Test fun `same start and end is never quiet`() {
        // start == end -> empty window, regardless of where "now" sits
        assertFalse(QuietHours.isWithinWindow(nowMin = 0, startMin = 8 * 60, endMin = 8 * 60))
        assertFalse(QuietHours.isWithinWindow(nowMin = 8 * 60, startMin = 8 * 60, endMin = 8 * 60))
        assertFalse(QuietHours.isWithinWindow(nowMin = 23 * 60, startMin = 8 * 60, endMin = 8 * 60))
    }

    @Test fun `normal range 10 to 12 covers only those two hours`() {
        val start = 10 * 60
        val end = 12 * 60
        assertFalse(QuietHours.isWithinWindow(nowMin = 9 * 60 + 59, startMin = start, endMin = end))
        assertTrue(QuietHours.isWithinWindow(nowMin = 10 * 60, startMin = start, endMin = end))
        assertTrue(QuietHours.isWithinWindow(nowMin = 11 * 60, startMin = start, endMin = end))
        assertTrue(QuietHours.isWithinWindow(nowMin = 11 * 60 + 59, startMin = start, endMin = end))
        assertFalse(QuietHours.isWithinWindow(nowMin = 12 * 60, startMin = start, endMin = end))
        assertFalse(QuietHours.isWithinWindow(nowMin = 13 * 60, startMin = start, endMin = end))
    }

    @Test fun `wrap around 22 to 07 covers late night and early morning`() {
        val start = 22 * 60
        val end = 7 * 60
        // late evening, after start
        assertTrue(QuietHours.isWithinWindow(nowMin = 22 * 60, startMin = start, endMin = end))
        assertTrue(QuietHours.isWithinWindow(nowMin = 23 * 60 + 30, startMin = start, endMin = end))
        // past midnight, before end
        assertTrue(QuietHours.isWithinWindow(nowMin = 0, startMin = start, endMin = end))
        assertTrue(QuietHours.isWithinWindow(nowMin = 6 * 60 + 59, startMin = start, endMin = end))
        // out of window (afternoon)
        assertFalse(QuietHours.isWithinWindow(nowMin = 12 * 60, startMin = start, endMin = end))
        assertFalse(QuietHours.isWithinWindow(nowMin = 21 * 60 + 59, startMin = start, endMin = end))
    }

    @Test fun `exact start boundary is quiet`() {
        // normal window
        assertTrue(QuietHours.isWithinWindow(nowMin = 10 * 60, startMin = 10 * 60, endMin = 12 * 60))
        // wrap-around window
        assertTrue(QuietHours.isWithinWindow(nowMin = 22 * 60, startMin = 22 * 60, endMin = 7 * 60))
    }

    @Test fun `exact end boundary is not quiet`() {
        // normal window: end is exclusive
        assertFalse(QuietHours.isWithinWindow(nowMin = 12 * 60, startMin = 10 * 60, endMin = 12 * 60))
        // wrap-around window: end is exclusive
        assertFalse(QuietHours.isWithinWindow(nowMin = 7 * 60, startMin = 22 * 60, endMin = 7 * 60))
    }
}
