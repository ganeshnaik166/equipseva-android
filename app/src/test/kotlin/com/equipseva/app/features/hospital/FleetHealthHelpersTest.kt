package com.equipseva.app.features.hospital

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins for the r1396 fleet-health uptime pill (bands → tone). */
class FleetHealthHelpersTest {

    @Test fun `healthy uptime reads Healthy with Success tone`() {
        assertEquals("Healthy" to PillKind.Success, uptimePillTextAndKind(99.5))
        assertEquals("Healthy" to PillKind.Success, uptimePillTextAndKind(98.0))
    }

    @Test fun `watch band reads Watch with Warn tone`() {
        assertEquals("Watch" to PillKind.Warn, uptimePillTextAndKind(95.0))
        assertEquals("Watch" to PillKind.Warn, uptimePillTextAndKind(90.0))
    }

    @Test fun `critical band reads Critical with Danger tone`() {
        assertEquals("Critical" to PillKind.Danger, uptimePillTextAndKind(89.9))
        assertEquals("Critical" to PillKind.Danger, uptimePillTextAndKind(0.0))
    }
}
