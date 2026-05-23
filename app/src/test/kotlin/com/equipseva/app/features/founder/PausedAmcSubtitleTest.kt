package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PausedAmcSubtitleTest {

    @Test fun `1 row reads singular silent service stop`() {
        assertEquals("1 silent service stop", pausedAmcSubtitle(1))
    }

    @Test fun `2 rows reads plural silent service stops`() {
        assertEquals("2 silent service stops", pausedAmcSubtitle(2))
    }

    @Test fun `0 rows returns null`() {
        assertNull(pausedAmcSubtitle(0))
    }

    @Test fun `silent service stop phrasing preserved verbatim`() {
        // Critical pin — distinguishes from a regular AMC pause
        // (which is explicit). "Silent stop" is when payments /
        // visits taper off without formal pause.
        val out = pausedAmcSubtitle(1)
        assertTrue(out!!.contains("silent service stop"))
    }

    @Test fun `large count interpolates with plural`() {
        assertEquals("42 silent service stops", pausedAmcSubtitle(42))
    }
}
