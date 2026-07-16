package com.equipseva.app.features.hospital

import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins for the r1419 chain-cockpit helpers. */
class ChainCockpitHelpersTest {

    @Test fun `site summary line reads open, done, disputed`() {
        assertEquals("3 open · 5 done (30d) · 1 disputed", chainSiteSummaryLine(3, 5, 1))
        assertEquals("0 open · 0 done (30d) · 0 disputed", chainSiteSummaryLine(0, 0, 0))
    }
}
