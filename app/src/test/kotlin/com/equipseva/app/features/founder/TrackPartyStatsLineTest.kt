package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the track-record stats line on the founder dispute detail.
 * Critical pin: parameterised wonLabel because hospital "wins" on
 * refund while engineer "wins" on release — pin the param so a
 * unifying refactor doesn't hard-code one side's vocabulary.
 */
class TrackPartyStatsLineTest {

    @Test fun `composes four stats with middle-dot separators`() {
        assertEquals(
            "10 total · 5 won · 3 lost · 2 open",
            trackPartyStatsLine(filed = 10, won = 5, wonLabel = "won", lost = 3, open = 2),
        )
    }

    @Test fun `won label parameterised for hospital side (refunded)`() {
        // Hospital wins on refund → wonLabel = "refunded".
        assertEquals(
            "10 total · 5 refunded · 3 lost · 2 open",
            trackPartyStatsLine(10, 5, "refunded", 3, 2),
        )
    }

    @Test fun `won label parameterised for engineer side (released)`() {
        // Engineer wins on release → wonLabel = "released".
        assertEquals(
            "10 total · 5 released · 3 lost · 2 open",
            trackPartyStatsLine(10, 5, "released", 3, 2),
        )
    }

    @Test fun `all-zero stats render verbatim (no special case)`() {
        assertEquals(
            "0 total · 0 won · 0 lost · 0 open",
            trackPartyStatsLine(0, 0, "won", 0, 0),
        )
    }

    @Test fun `middle-dot separator is U+00B7 not bullet`() {
        val out = trackPartyStatsLine(1, 1, "won", 1, 1)
        assertTrue(out.contains('·'))
        assertEquals(false, out.contains('•'))
    }

    @Test fun `total suffix on first stat is preserved verbatim`() {
        // Pin "N total" — load-bearing anchor for the breakdown.
        val out = trackPartyStatsLine(5, 0, "won", 0, 0)
        assertTrue(out.startsWith("5 total "))
    }

    @Test fun `lost stat always uses literal lost (not parameterised)`() {
        // Pin — only wonLabel is parameterised. lost and open are
        // semantically neutral and use fixed words.
        val out = trackPartyStatsLine(0, 0, "anything", 7, 0)
        assertTrue(out.contains("7 lost"))
    }

    @Test fun `open stat always uses literal open (not parameterised)`() {
        val out = trackPartyStatsLine(0, 0, "anything", 0, 7)
        assertTrue(out.endsWith("7 open"))
    }
}
