package com.equipseva.app.features.hospital

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins for the r1414 NABH bundle helpers. */
class NabhBundleHelpersTest {

    @Test fun `sign-off status from timestamps`() {
        assertEquals("Both signed", nabhSignOffStatus("2026-01-01", "2026-01-02"))
        assertEquals("Engineer signed", nabhSignOffStatus("2026-01-01", null))
        assertEquals("Hospital signed", nabhSignOffStatus("  ", "2026-01-02"))
        assertEquals("Unsigned", nabhSignOffStatus(null, ""))
    }

    @Test fun `check pill reflects pass, fail, not-recorded`() {
        assertEquals("IEC 62353 ✓" to PillKind.Success, nabhCheckPill("IEC 62353", true))
        assertEquals("Calibration ✗" to PillKind.Danger, nabhCheckPill("Calibration", false))
        assertEquals("IEC 62353 —" to PillKind.Neutral, nabhCheckPill("IEC 62353", null))
    }
}
