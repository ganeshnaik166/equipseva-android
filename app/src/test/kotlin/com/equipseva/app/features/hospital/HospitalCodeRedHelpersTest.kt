package com.equipseva.app.features.hospital

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins for the r1426 hospital Code Red helpers. */
class HospitalCodeRedHelpersTest {

    @Test fun `status pill maps request lifecycle`() {
        assertEquals("Paging engineers" to PillKind.Warn, codeRedRequestStatusPill("open"))
        assertEquals("Engineer accepted" to PillKind.Success, codeRedRequestStatusPill("engineer_accepted"))
        assertEquals("Resolved" to PillKind.Success, codeRedRequestStatusPill("resolved"))
        assertEquals("Timed out" to PillKind.Danger, codeRedRequestStatusPill("timed_out"))
        assertEquals("Cancelled" to PillKind.Neutral, codeRedRequestStatusPill("cancelled"))
    }

    @Test fun `description must be 10 to 2000 chars`() {
        assertEquals(false, isValidCodeRedDescription("too short"))
        assertEquals(true, isValidCodeRedDescription("Monitor dead in ICU"))
        assertEquals(false, isValidCodeRedDescription("   nine chr   "))
        assertEquals(false, isValidCodeRedDescription("x".repeat(2001)))
        assertEquals(true, isValidCodeRedDescription("x".repeat(2000)))
    }

    @Test fun `fee ceiling parses within 0 to 50000`() {
        assertEquals(5000.0, parseFeeCeiling("5000"))
        assertEquals(0.0, parseFeeCeiling("0"))
        assertEquals(null, parseFeeCeiling("-1"))
        assertEquals(null, parseFeeCeiling("50001"))
        assertEquals(null, parseFeeCeiling("abc"))
    }

    @Test fun `sla label reads naturally`() {
        assertEquals("30 minutes", slaMinutesLabel(30))
        assertEquals("1 hour", slaMinutesLabel(60))
        assertEquals("2 hours", slaMinutesLabel(120))
        assertEquals("4 hours", slaMinutesLabel(240))
    }

    @Test fun `equipment label uses repair category names`() {
        assertEquals("Patient monitoring", equipmentTypeLabel("patient_monitoring"))
        assertEquals("Laboratory", equipmentTypeLabel("laboratory"))
    }
}
