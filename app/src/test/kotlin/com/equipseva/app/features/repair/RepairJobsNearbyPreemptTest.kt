package com.equipseva.app.features.repair

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the r1497 nearby-feed pre-empt: an engineer with NO service location
 * gets an actionable message instead of the proximity RPC's server-side
 * failure (a generic 42501 whose copy misleadingly blames KYC — observed
 * live on the play-review engineer account).
 */
class RepairJobsNearbyPreemptTest {

    @Test fun `preempts when base is loaded and coords are missing`() {
        assertTrue(shouldPreemptNearbyFetch(50, true, true, null, null))
    }

    @Test fun `preempts when only one coordinate is missing (corrupt base)`() {
        assertTrue(shouldPreemptNearbyFetch(50, true, true, 17.4, null))
        assertTrue(shouldPreemptNearbyFetch(50, true, true, null, 78.5))
    }

    @Test fun `never preempts before the engineer row has loaded`() {
        // Coords are null merely because the fetch hasn't finished (or
        // failed) — pre-empting here would wrongly lock out a configured
        // engineer on a network blip.
        assertFalse(shouldPreemptNearbyFetch(50, true, false, null, null))
    }

    @Test fun `never preempts the All filter (non-geo query works without a base)`() {
        assertFalse(shouldPreemptNearbyFetch(null, true, true, null, null))
    }

    @Test fun `never preempts a text search (routes to the non-geo query)`() {
        assertFalse(shouldPreemptNearbyFetch(50, false, true, null, null))
    }

    @Test fun `never preempts an engineer with a configured base`() {
        assertFalse(shouldPreemptNearbyFetch(50, true, true, 17.4, 78.5))
    }

    @Test fun `message names both escape hatches that exist on the screen`() {
        // Pin the two affordances the copy points at — the map's chip and
        // the All radius filter. Renaming either UI element must fail here
        // so the copy is updated in lockstep.
        assertTrue(MISSING_SERVICE_LOCATION_MESSAGE.contains("Set service location"))
        assertTrue(MISSING_SERVICE_LOCATION_MESSAGE.contains("All"))
        // And it must NOT blame KYC — that was the misleading copy this
        // replaces.
        assertFalse(MISSING_SERVICE_LOCATION_MESSAGE.contains("KYC", ignoreCase = true))
    }
}
