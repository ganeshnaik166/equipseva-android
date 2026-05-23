package com.equipseva.app.features.repair.directory

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the availability pill on the engineer public profile.
 *
 * Critical pin: "Busy" + Warn (NOT Danger). Engineer being busy is
 * normal — Warn (amber) is the right urgency level for "schedule
 * for later"; Danger (red) would over-escalate.
 */
class EngineerAvailabilityPillTest {

    @Test fun `available true reads Available with Success`() {
        assertEquals(
            "Available" to PillKind.Success,
            engineerAvailabilityPill(true),
        )
    }

    @Test fun `available false reads Busy with Warn (NOT Danger)`() {
        // Critical pin — Warn not Danger. A refactor to Danger would
        // over-escalate the "engineer is busy" signal.
        assertEquals(
            "Busy" to PillKind.Warn,
            engineerAvailabilityPill(false),
        )
    }

    @Test fun `Busy literal preserved over Unavailable`() {
        // Pin "Busy" — preserves the temporary-vs-permanent
        // distinction (engineers can flip back to available).
        val (text, _) = engineerAvailabilityPill(false)
        assertEquals("Busy", text)
    }

    @Test fun `Available literal preserved over Online`() {
        // Pin "Available" — semantic intent (taking jobs), distinct
        // from "Online" (just-app-open presence signal).
        val (text, _) = engineerAvailabilityPill(true)
        assertEquals("Available", text)
    }

    @Test fun `success and warn pair distinct kinds`() {
        // Pin asymmetric kinds — same wire data, different visual
        // weight by state.
        val (_, availableKind) = engineerAvailabilityPill(true)
        val (_, busyKind) = engineerAvailabilityPill(false)
        assertEquals(PillKind.Success, availableKind)
        assertEquals(PillKind.Warn, busyKind)
    }
}
