package com.equipseva.app.core.data.hospital

import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins for the r1398 PM-calendar helpers: header roll-up + due-date phrasing. */
class PmCalendarSummaryTest {

    private fun pm(
        id: String = "p1",
        status: String = "upcoming",
        days: Double = 10.0,
    ) = PmCalendarRepository.PmScheduleItem(
        id = id,
        equipmentType = "patient_monitoring",
        equipmentBrand = "Philips",
        equipmentModel = "MX40",
        equipmentSerial = "SN$id",
        intervalDays = 90,
        lastServiceAt = "2026-04-01T00:00:00Z",
        nextPmDueAt = "2026-07-25T00:00:00Z",
        daysUntilDue = days,
        status = status,
    )

    // ---- summarisePmCalendar ------------------------------------------

    @Test fun `empty list rolls up to zeros`() {
        val h = summarisePmCalendar(emptyList())
        assertEquals(0, h.total); assertEquals(0, h.overdue); assertEquals(0, h.dueSoon); assertEquals(0, h.upcoming)
    }

    @Test fun `counts by status, folding scheduled into upcoming`() {
        val items = listOf(
            pm(id = "a", status = "overdue", days = -3.0),
            pm(id = "b", status = "due", days = 2.0),
            pm(id = "c", status = "upcoming", days = 15.0),
            pm(id = "d", status = "scheduled", days = 50.0),
        )
        val h = summarisePmCalendar(items)
        assertEquals(4, h.total)
        assertEquals(1, h.overdue)
        assertEquals(1, h.dueSoon)
        assertEquals(2, h.upcoming) // upcoming + scheduled
    }

    // ---- formatDaysUntilDue -------------------------------------------

    @Test fun `overdue reads with a positive day count`() {
        assertEquals("Overdue by 3 days", formatDaysUntilDue(-3.0))
        assertEquals("Overdue by 1 day", formatDaysUntilDue(-1.0))
    }

    @Test fun `within half a day of zero reads due today`() {
        assertEquals("Due today", formatDaysUntilDue(0.0))
        assertEquals("Due today", formatDaysUntilDue(0.4))
        assertEquals("Due today", formatDaysUntilDue(-0.4))
    }

    @Test fun `future reads due in N days with plural handling`() {
        assertEquals("Due in 1 day", formatDaysUntilDue(1.0))
        assertEquals("Due in 5 days", formatDaysUntilDue(5.0))
        assertEquals("Due in 10 days", formatDaysUntilDue(9.6))
    }
}
