package com.equipseva.app.features.founder

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class RotationRowPillsTest {

    // ---- rotationPriorityPill ----------------------------------------

    @Test fun `isPrimary true reads Primary with Info`() {
        assertEquals(
            "Primary" to PillKind.Info,
            rotationPriorityPill(isPrimary = true, priority = 1),
        )
    }

    @Test fun `isPrimary false reads hash-N with Default`() {
        // Critical pin — "#N" with U+0023 hash prefix, distinguishing
        // rank from count. A bare "2" would read as "2 engineers" or
        // similar.
        assertEquals(
            "#2" to PillKind.Default,
            rotationPriorityPill(isPrimary = false, priority = 2),
        )
        assertEquals(
            "#5" to PillKind.Default,
            rotationPriorityPill(isPrimary = false, priority = 5),
        )
    }

    @Test fun `isPrimary true ignores priority value (shows Primary)`() {
        // Pin precedence — isPrimary takes priority over the int.
        // A primary engineer might have any priority value
        // historically; pin "Primary" wins.
        assertEquals(
            "Primary" to PillKind.Info,
            rotationPriorityPill(isPrimary = true, priority = 99),
        )
    }

    @Test fun `Primary literal preserved over Lead or Main`() {
        // Pin — cross-surface vocabulary anchor (matches
        // engineerRolePillLabel which also uses "Primary").
        val (text, _) = rotationPriorityPill(true, 1)
        assertEquals("Primary", text)
    }

    // ---- rotationAvailabilityPill ------------------------------------

    @Test fun `isAvailable true reads Available with Success`() {
        assertEquals(
            "Available" to PillKind.Success,
            rotationAvailabilityPill(true),
        )
    }

    @Test fun `isAvailable false reads Unavailable with Warn NOT Danger`() {
        // Critical pin — Warn not Danger. Unavailable is operational
        // reality (engineer on another job), not an alarm.
        assertEquals(
            "Unavailable" to PillKind.Warn,
            rotationAvailabilityPill(false),
        )
    }

    @Test fun `cross-helper distinction — rotation says Unavailable, profile says Busy`() {
        // Pin the surface-specific vocabulary asymmetry. Rotation is
        // administrative (founder pool review); profile is hospital-
        // facing (friendlier "Busy").
        val (text, _) = rotationAvailabilityPill(false)
        assertEquals("Unavailable", text)
        assertTrue(text != "Busy")
    }
}
