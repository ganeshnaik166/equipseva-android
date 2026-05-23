package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SimpleQueueCountSubtitleTest {

    @Test fun `count and noun interpolate verbatim`() {
        assertEquals("5 open", simpleQueueCountSubtitle(5, "open"))
        assertEquals("3 suspended", simpleQueueCountSubtitle(3, "suspended"))
    }

    @Test fun `0 returns null`() {
        assertNull(simpleQueueCountSubtitle(0, "open"))
    }

    @Test fun `negative returns null (defensive)`() {
        assertNull(simpleQueueCountSubtitle(-1, "open"))
    }

    @Test fun `1 reads singular shape (status is state, not count-noun)`() {
        // Pin plural-blind — "1 open" / "1 suspended" reads fine
        // because the status is a state, not a count-noun.
        assertEquals("1 open", simpleQueueCountSubtitle(1, "open"))
        assertEquals("1 suspended", simpleQueueCountSubtitle(1, "suspended"))
    }

    @Test fun `noun passes through verbatim`() {
        // Pin no transformation. A refactor to title-case would
        // surface "Open" instead of "open" — breaks lowercase-status
        // convention.
        assertEquals(
            "5 SOMETHING",
            simpleQueueCountSubtitle(5, "SOMETHING"),
        )
    }

    @Test fun `large count interpolates verbatim`() {
        assertEquals(
            "100 open",
            simpleQueueCountSubtitle(100, "open"),
        )
    }
}
