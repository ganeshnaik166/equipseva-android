package com.equipseva.app.features.amc

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the r1427 gate for the "Assign engineer" CTA on an AMC visit —
 * mirrors the server guard in assign_next_available_amc_engineer so the
 * button never appears on a row the RPC would reject.
 */
class CanAssignAmcVisitTest {

    @Test fun `unassigned and not started is assignable`() {
        assertEquals(true, canAssignAmcVisit("requested", null))
        assertEquals(true, canAssignAmcVisit("assigned", ""))
        assertEquals(true, canAssignAmcVisit("scheduled", "   "))
    }

    @Test fun `already having an engineer is not assignable`() {
        assertEquals(false, canAssignAmcVisit("requested", "eng-123"))
    }

    @Test fun `started or terminal statuses are not assignable`() {
        assertEquals(false, canAssignAmcVisit("en_route", null))
        assertEquals(false, canAssignAmcVisit("in_progress", null))
        assertEquals(false, canAssignAmcVisit("completed", null))
        assertEquals(false, canAssignAmcVisit("disputed", null))
        assertEquals(false, canAssignAmcVisit("cancelled", null))
    }

    @Test fun `status match is case-insensitive`() {
        assertEquals(false, canAssignAmcVisit("IN_PROGRESS", null))
        assertEquals(false, canAssignAmcVisit(" Completed ", null))
    }
}
