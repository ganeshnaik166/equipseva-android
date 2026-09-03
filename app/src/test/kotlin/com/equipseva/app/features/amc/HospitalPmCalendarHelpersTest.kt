package com.equipseva.app.features.amc

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the pure helpers behind [HospitalPmCalendarScreen] (round3770) —
 * the first Android client of the round507 Predictive PM Calendar
 * backend.
 */
class HospitalPmCalendarHelpersTest {

    private fun item(
        id: String = "row-1",
        equipmentType: String = "dental",
        equipmentBrand: String? = null,
        equipmentModel: String? = null,
        equipmentSerial: String? = null,
        intervalDays: Int = 180,
        lastServiceAt: String? = null,
        nextPmDueAt: String = "2026-10-01T00:00:00Z",
        daysUntilDue: Double = 10.0,
        status: String = "scheduled",
    ) = HospitalPmCalendarRepository.PmScheduleItem(
        id = id,
        equipmentType = equipmentType,
        equipmentBrand = equipmentBrand,
        equipmentModel = equipmentModel,
        equipmentSerial = equipmentSerial,
        intervalDays = intervalDays,
        lastServiceAt = lastServiceAt,
        nextPmDueAt = nextPmDueAt,
        daysUntilDue = daysUntilDue,
        status = status,
    )

    // ---------------------------------------------------------------
    // pmStatusLabelAndKind
    // ---------------------------------------------------------------

    @Test fun `overdue renders Danger`() {
        assertEquals("Overdue" to PillKind.Danger, pmStatusLabelAndKind("overdue"))
    }

    @Test fun `due renders Warn`() {
        assertEquals("Due soon" to PillKind.Warn, pmStatusLabelAndKind("due"))
    }

    @Test fun `upcoming renders Info`() {
        assertEquals("Upcoming" to PillKind.Info, pmStatusLabelAndKind("upcoming"))
    }

    @Test fun `scheduled renders Neutral`() {
        assertEquals("Scheduled" to PillKind.Neutral, pmStatusLabelAndKind("scheduled"))
    }

    @Test fun `unknown status falls back to capitalised label + Neutral`() {
        assertEquals("Completed" to PillKind.Neutral, pmStatusLabelAndKind("completed"))
    }

    // ---------------------------------------------------------------
    // pmDueInText
    // ---------------------------------------------------------------

    @Test fun `overdue status always phrases as overdue, floor 1 day`() {
        // n rounds to 0 but status says overdue (crossed the line
        // moments ago) — must not read "Due today".
        assertEquals("Overdue by 1 day", pmDueInText("overdue", -0.2))
    }

    @Test fun `overdue by several whole days`() {
        assertEquals("Overdue by 12 days", pmDueInText("overdue", -12.0))
    }

    @Test fun `due today`() {
        assertEquals("Due today", pmDueInText("due", 0.4))
    }

    @Test fun `due in exactly 1 day is singular`() {
        assertEquals("Due in 1 day", pmDueInText("due", 1.0))
    }

    @Test fun `due in N days`() {
        assertEquals("Due in 5 days", pmDueInText("upcoming", 5.4))
    }

    @Test fun `negative days_until_due with a non-overdue status still reads as overdue defensively`() {
        assertEquals("Overdue by 2 days", pmDueInText("due", -2.0))
    }

    // ---------------------------------------------------------------
    // pmEquipmentSubtitle
    // ---------------------------------------------------------------

    @Test fun `subtitle blank when brand, model, serial all absent`() {
        assertEquals("", pmEquipmentSubtitle(item()))
    }

    @Test fun `subtitle joins brand and model`() {
        assertEquals(
            "Sirona · Intego",
            pmEquipmentSubtitle(item(equipmentBrand = "Sirona", equipmentModel = "Intego")),
        )
    }

    @Test fun `subtitle falls back to serial only`() {
        assertEquals("S/N XY123", pmEquipmentSubtitle(item(equipmentSerial = "XY123")))
    }

    @Test fun `subtitle includes brand, model, and serial together`() {
        assertEquals(
            "Sirona · Intego · S/N XY123",
            pmEquipmentSubtitle(
                item(equipmentBrand = "Sirona", equipmentModel = "Intego", equipmentSerial = "XY123"),
            ),
        )
    }

    @Test fun `blank brand string is treated as absent`() {
        assertEquals(
            "Intego",
            pmEquipmentSubtitle(item(equipmentBrand = "  ", equipmentModel = "Intego")),
        )
    }

    // ---------------------------------------------------------------
    // groupPmItemsByStatus
    // ---------------------------------------------------------------

    @Test fun `groups are ordered overdue, due, upcoming, scheduled and skip empty groups`() {
        val rows = listOf(
            item(id = "a", status = "scheduled"),
            item(id = "b", status = "overdue"),
            item(id = "c", status = "due"),
        )
        val grouped = groupPmItemsByStatus(rows)
        assertEquals(listOf("overdue", "due", "scheduled"), grouped.map { it.first })
        assertEquals(listOf("b"), grouped.first { it.first == "overdue" }.second.map { it.id })
    }

    @Test fun `empty input yields no groups`() {
        assertEquals(emptyList<Any>(), groupPmItemsByStatus(emptyList()))
    }

    @Test fun `an unrecognised status is appended rather than dropped`() {
        val rows = listOf(item(id = "x", status = "mystery_state"))
        val grouped = groupPmItemsByStatus(rows)
        assertEquals(listOf("mystery_state" to rows), grouped)
    }

    // ---------------------------------------------------------------
    // pmSectionHeader
    // ---------------------------------------------------------------

    @Test fun `section header pluralises via explicit count, not grammar`() {
        assertEquals("Overdue (3)", pmSectionHeader("overdue", 3))
        assertEquals("Due this week (1)", pmSectionHeader("due", 1))
        assertEquals("Due this month (0)", pmSectionHeader("upcoming", 0))
        assertEquals("Scheduled (7)", pmSectionHeader("scheduled", 7))
    }
}
