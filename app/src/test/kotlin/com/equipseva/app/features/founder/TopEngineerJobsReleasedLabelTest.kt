package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the singular/plural split on the top-engineer leaderboard
 * subtitle ("N job(s) released").
 *
 * Critical region: 1 → singular "job". A regression to always-"jobs"
 * would surface "1 jobs released" on an engineer's first release —
 * the most visible row in the dashboard's first-time-render window.
 */
class TopEngineerJobsReleasedLabelTest {

    @Test fun `1 job uses singular`() {
        assertEquals("1 job released", topEngineerJobsReleasedLabel(1L))
    }

    @Test fun `2 jobs uses plural`() {
        assertEquals("2 jobs released", topEngineerJobsReleasedLabel(2L))
    }

    @Test fun `5 jobs uses plural`() {
        assertEquals("5 jobs released", topEngineerJobsReleasedLabel(5L))
    }

    @Test fun `large count interpolates verbatim`() {
        assertEquals("999 jobs released", topEngineerJobsReleasedLabel(999L))
    }

    @Test fun `zero jobs uses plural (caller gates on positive — defensive)`() {
        // The leaderboard RPC filters jobsCompleted > 0 before
        // returning rows, but pin a sensible fallback.
        assertEquals("0 jobs released", topEngineerJobsReleasedLabel(0L))
    }

    @Test fun `singular branch fires on exact 1 not on a range`() {
        // Pin so a refactor to a range gate doesn't surface
        // "0 job released" or "2 job released".
        assertEquals(false, topEngineerJobsReleasedLabel(0L).endsWith("job released"))
        assertEquals(true, topEngineerJobsReleasedLabel(1L).endsWith("job released"))
        assertEquals(false, topEngineerJobsReleasedLabel(2L).endsWith("job released"))
    }
}
