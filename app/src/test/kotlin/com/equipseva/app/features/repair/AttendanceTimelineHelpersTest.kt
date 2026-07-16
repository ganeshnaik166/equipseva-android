package com.equipseva.app.features.repair

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins for the r1409 attendance-timeline helpers. */
class AttendanceTimelineHelpersTest {

    @Test fun `event kinds map to labels`() {
        assertEquals("Arrival check-in", attendanceEventLabel("arrival_checkin"))
        assertEquals("Departure check-out", attendanceEventLabel("departure_checkout"))
    }

    @Test fun `unknown event kind de-snakes`() {
        assertEquals("Some event", attendanceEventLabel("some_event"))
    }

    @Test fun `distance formats metres then km`() {
        assertEquals("—", formatDistanceM(null))
        assertEquals("120 m", formatDistanceM(120.0))
        assertEquals("999 m", formatDistanceM(999.0))
        assertEquals("1 km", formatDistanceM(1000.0))
        assertEquals("1.2 km", formatDistanceM(1234.0))
    }

    @Test fun `suspicious flag drives the pill`() {
        assertEquals("On-site" to PillKind.Success, attendanceSuspiciousPill(false))
        assertEquals("Far from site" to PillKind.Danger, attendanceSuspiciousPill(true))
    }

    // r1443 — next check-in/out action.

    @Test fun `next event toggles from the latest`() {
        assertEquals("arrival_checkin", nextAttendanceEvent(null))
        assertEquals("arrival_checkin", nextAttendanceEvent("departure_checkout"))
        assertEquals("departure_checkout", nextAttendanceEvent("arrival_checkin"))
    }
}
