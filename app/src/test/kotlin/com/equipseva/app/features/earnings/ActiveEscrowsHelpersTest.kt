package com.equipseva.app.features.earnings

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ActiveEscrowsHelpersTest {

    // ---- activeEscrowsSubtitle ---------------------------------------

    @Test fun `subtitle reads count open when non-empty`() {
        assertEquals("3 open", activeEscrowsSubtitle(3))
    }

    @Test fun `subtitle returns null on empty`() {
        assertNull(activeEscrowsSubtitle(0))
    }

    // ---- activeEscrowStatusPill --------------------------------------

    @Test fun `in_dispute maps to Disputed + Danger`() {
        assertEquals(
            "Disputed" to PillKind.Danger,
            activeEscrowStatusPill("in_dispute"),
        )
    }

    @Test fun `held maps to Held + Success (engineer-facing)`() {
        // Critical pin — Success not Warn. Held = hospital paid;
        // money is committed; engineer should feel safe, not alarmed.
        assertEquals(
            "Held" to PillKind.Success,
            activeEscrowStatusPill("held"),
        )
    }

    @Test fun `pending maps to Awaiting payment + Warn`() {
        // Hospital hasn't paid yet — engineer should be aware.
        assertEquals(
            "Awaiting payment" to PillKind.Warn,
            activeEscrowStatusPill("pending"),
        )
    }

    @Test fun `unknown status falls through to raw + Default`() {
        assertEquals(
            "some_future_state" to PillKind.Default,
            activeEscrowStatusPill("some_future_state"),
        )
    }

    @Test fun `case-sensitive — Held capital H falls through to Default`() {
        // Pin exact-match. Server wire is lowercase.
        assertEquals(
            "Held" to PillKind.Default,
            activeEscrowStatusPill("Held"),
        )
    }
}
