package com.equipseva.app.features.engineer

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the AMC-visit status → [PillKind] color mapping shown on the
 * engineer's AMC-visits list. The mapping isn't just cosmetic — a
 * mistakenly Success-coloured "cancelled" visit would mislead the
 * engineer into thinking the visit was completed. Caught here so the
 * lower-noise (Default/Info) bucket for in-flight states stays put.
 */
class PillForStatusTest {

    @Test fun `completed maps to Success`() {
        assertEquals(PillKind.Success, pillForStatus("completed"))
    }

    @Test fun `in_progress maps to Info`() {
        assertEquals(PillKind.Info, pillForStatus("in_progress"))
    }

    @Test fun `assigned and en_route both map to Info`() {
        assertEquals(PillKind.Info, pillForStatus("assigned"))
        assertEquals(PillKind.Info, pillForStatus("en_route"))
    }

    @Test fun `cancelled maps to Default (de-emphasised)`() {
        assertEquals(PillKind.Default, pillForStatus("cancelled"))
    }

    @Test fun `unknown status falls back to Warn so it stands out`() {
        // Warn is the loudest pill kind short of Danger — by design,
        // an unrecognised status should be visible so an engineer
        // notices the row before treating it as routine.
        assertEquals(PillKind.Warn, pillForStatus("future_state"))
        assertEquals(PillKind.Warn, pillForStatus(""))
    }

    @Test fun `case-insensitive on the storage key`() {
        assertEquals(PillKind.Success, pillForStatus("COMPLETED"))
        assertEquals(PillKind.Info, pillForStatus("In_Progress"))
    }
}
