package com.equipseva.app.features.repair.directory

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins completionStatValue (r1486): an engineer with no completed jobs shows
 * the no-data em-dash "—" rather than a misleading 0% completion score, while
 * engineers with jobs render the real rate (tolerating both 0..1 and 0..100
 * wire shapes via formatCompletionRatePct).
 */
class CompletionStatValueTest {

    @Test fun `zero jobs shows the no-data dash`() {
        assertEquals("—", completionStatValue(totalJobs = 0, completionRate = 0.0))
    }

    @Test fun `zero jobs shows dash even if a stray rate is present`() {
        assertEquals("—", completionStatValue(totalJobs = 0, completionRate = 0.97))
    }

    @Test fun `jobs with a fractional rate renders a percentage`() {
        assertEquals("98%", completionStatValue(totalJobs = 5, completionRate = 0.98))
    }

    @Test fun `jobs with a 0-100 rate renders a percentage`() {
        assertEquals("94%", completionStatValue(totalJobs = 12, completionRate = 94.0))
    }

    @Test fun `jobs with a genuine zero rate still shows 0 percent`() {
        // Has jobs but completed none — an honest 0%, not the no-data case.
        assertEquals("0%", completionStatValue(totalJobs = 3, completionRate = 0.0))
    }
}
