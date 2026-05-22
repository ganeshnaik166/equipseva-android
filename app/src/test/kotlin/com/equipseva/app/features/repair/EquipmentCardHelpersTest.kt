package com.equipseva.app.features.repair

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the two pure helpers behind RepairJobDetail's EquipmentCard:
 *
 *   * textOrDash — generic "value or em-dash" fallback used on the
 *     Brand / Model rows when the value is null / blank.
 *   * equipmentScheduleLine — date + slot composition with
 *     null / blank handling on both sides and em-dash fallback when
 *     both are missing.
 */
class EquipmentCardHelpersTest {

    // ---- textOrDash ----

    @Test fun `present value passes through`() {
        assertEquals("GE", textOrDash("GE"))
        assertEquals("Logiq P5", textOrDash("Logiq P5"))
    }

    @Test fun `null value renders em-dash`() {
        assertEquals("—", textOrDash(null))
    }

    @Test fun `blank value renders em-dash`() {
        assertEquals("—", textOrDash("  "))
        assertEquals("—", textOrDash(""))
    }

    @Test fun `em-dash is U+2014 not ASCII hyphen`() {
        val out = textOrDash(null)
        assertEquals(true, out.contains('—'))
        assertEquals(false, out.contains('-'))
    }

    // ---- equipmentScheduleLine ----

    @Test fun `date + slot join with single space`() {
        assertEquals(
            "2026-05-22 morning",
            equipmentScheduleLine(scheduledDate = "2026-05-22", scheduledTimeSlot = "morning"),
        )
    }

    @Test fun `date only without slot drops trailing space`() {
        assertEquals(
            "2026-05-22",
            equipmentScheduleLine(scheduledDate = "2026-05-22", scheduledTimeSlot = null),
        )
    }

    @Test fun `slot only without date drops leading space`() {
        assertEquals(
            "morning",
            equipmentScheduleLine(scheduledDate = null, scheduledTimeSlot = "morning"),
        )
    }

    @Test fun `both null returns em-dash`() {
        assertEquals("—", equipmentScheduleLine(scheduledDate = null, scheduledTimeSlot = null))
    }

    @Test fun `both blank returns em-dash`() {
        assertEquals("—", equipmentScheduleLine(scheduledDate = "  ", scheduledTimeSlot = ""))
    }

    @Test fun `blank date + present slot returns slot only (no leading space)`() {
        // Pin so an empty date doesn't surface as " morning" with a
        // leading space.
        assertEquals(
            "morning",
            equipmentScheduleLine(scheduledDate = "", scheduledTimeSlot = "morning"),
        )
    }

    @Test fun `present date + blank slot returns date only (no trailing space)`() {
        assertEquals(
            "2026-05-22",
            equipmentScheduleLine(scheduledDate = "2026-05-22", scheduledTimeSlot = "  "),
        )
    }

    @Test fun `em-dash fallback uses U+2014 (typographic dash)`() {
        val out = equipmentScheduleLine(null, null)
        assertEquals(true, out.contains('—'))
    }
}
