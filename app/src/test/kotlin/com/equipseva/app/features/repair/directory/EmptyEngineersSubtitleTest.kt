package com.equipseva.app.features.repair.directory

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the engineer-directory empty-state subtitle split. The
 * critical UX distinction: filtersActive=true is recoverable (the
 * Reset button is shown alongside), filtersActive=false is passive
 * (no engineers nearby — no action helps).
 *
 * Pin so a refactor that collapses the two branches doesn't
 * promise users a "wider district" recovery affordance that doesn't
 * apply.
 */
class EmptyEngineersSubtitleTest {

    @Test fun `filtersActive true suggests widening`() {
        assertEquals(
            "Try a wider district or fewer filters",
            emptyEngineersSubtitle(filtersActive = true),
        )
    }

    @Test fun `filtersActive false uses passive area-empty copy`() {
        assertEquals(
            "No verified engineers in your area yet",
            emptyEngineersSubtitle(filtersActive = false),
        )
    }

    @Test fun `filtersActive false does NOT suggest widening (no filter to widen)`() {
        // Pin so a refactor that collapsed the branches doesn't
        // resurrect the "try widening" copy when there's nothing
        // to widen.
        val passive = emptyEngineersSubtitle(filtersActive = false)
        assertEquals(false, passive.contains("widen", ignoreCase = true))
        assertEquals(false, passive.contains("filter", ignoreCase = true))
    }

    @Test fun `filtersActive true subtitle mentions filters (recovery affordance)`() {
        // The Reset button is rendered alongside; the subtitle copy
        // must reference filters so the user knows what they need to
        // touch.
        val active = emptyEngineersSubtitle(filtersActive = true)
        assertEquals(true, active.contains("filter", ignoreCase = true))
    }

    @Test fun `branches produce distinct copy`() {
        val active = emptyEngineersSubtitle(filtersActive = true)
        val passive = emptyEngineersSubtitle(filtersActive = false)
        assertEquals(true, active != passive)
    }
}
