package com.equipseva.app.features.amc

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

/**
 * Pins the r1510 overdue-aware AMC visit status: a past-scheduled OPEN visit
 * reads "Overdue"; terminal states and unparseable/missing dates never do.
 * (Found live: two visits 5–7 weeks past their date rendered as calm
 * "Requested" rows on the paying hospital's contract.)
 */
class AmcVisitStatusDisplayTest {

    private val today: LocalDate = LocalDate.of(2026, 7, 18)

    @Test fun `past-scheduled open visit reads Overdue`() {
        val d = amcVisitStatusDisplay("requested", "2026-05-27", today)
        assertEquals("Overdue", d.label)
        assertTrue(d.overdue)
    }

    @Test fun `due today is NOT overdue (the visit still has all day)`() {
        val d = amcVisitStatusDisplay("requested", "2026-07-18", today)
        assertEquals("Requested", d.label)
        assertFalse(d.overdue)
    }

    @Test fun `future visit keeps its raw status`() {
        val d = amcVisitStatusDisplay("requested", "2026-07-27", today)
        assertEquals("Requested", d.label)
        assertFalse(d.overdue)
    }

    @Test fun `completed and cancelled never read Overdue even when past`() {
        assertFalse(amcVisitStatusDisplay("completed", "2026-05-27", today).overdue)
        assertEquals("Completed", amcVisitStatusDisplay("completed", "2026-05-27", today).label)
        assertFalse(amcVisitStatusDisplay("cancelled", "2026-05-27", today).overdue)
    }

    @Test fun `missing or unparseable date never flags overdue`() {
        assertFalse(amcVisitStatusDisplay("requested", null, today).overdue)
        assertFalse(amcVisitStatusDisplay("requested", "garbage", today).overdue)
        assertEquals("Requested", amcVisitStatusDisplay("requested", null, today).label)
    }

    @Test fun `full ISO timestamps are tolerated via the 10-char date slice`() {
        val d = amcVisitStatusDisplay("assigned", "2026-05-27T07:00:00Z", today)
        assertTrue(d.overdue)
    }
}
