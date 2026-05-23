package com.equipseva.app.features.hospital

import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.features.engineer.engineerDisputePillTextAndKind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the three pure helpers behind the hospital's My-Disputes row.
 * Critical cross-surface invariant: same wire data, INVERTED role-aware
 * copy and a deliberate Default-not-Success mapping on "release"
 * because release is the unfavourable outcome for the hospital.
 */
class HospitalDisputeRowHelpersTest {

    // ---- hospitalDisputePillTextAndKind ------------------------------

    @Test fun `in_dispute status wins over outcome — Under review + Danger`() {
        assertEquals(
            "Under review" to PillKind.Danger,
            hospitalDisputePillTextAndKind("in_dispute", null),
        )
        assertEquals(
            "Under review" to PillKind.Danger,
            hospitalDisputePillTextAndKind("in_dispute", "release"),
        )
        assertEquals(
            "Under review" to PillKind.Danger,
            hospitalDisputePillTextAndKind("in_dispute", "refund"),
        )
    }

    @Test fun `release outcome reads Released to engineer + Default (NOT Warn, NOT Success)`() {
        // Critical pin — role-aware "engineer" word. AND the colour
        // is Default, not Warn (Warn would read as "in progress")
        // and not Success (release is unfavourable for the hospital).
        // A refactor that harmonised this with the engineer-side
        // Success would visually mislead hospital users.
        assertEquals(
            "Released to engineer" to PillKind.Default,
            hospitalDisputePillTextAndKind("resolved", "release"),
        )
    }

    @Test fun `refund outcome reads Refunded to you + Success`() {
        // Role-aware "you" — the hospital sees their own pronoun.
        // Refund IS the good outcome for the hospital → Success.
        assertEquals(
            "Refunded to you" to PillKind.Success,
            hospitalDisputePillTextAndKind("resolved", "refund"),
        )
    }

    @Test fun `unknown status falls through to status capitalised + Default`() {
        assertEquals(
            "Pending" to PillKind.Default,
            hospitalDisputePillTextAndKind("pending", null),
        )
    }

    @Test fun `cross-surface invariant — hospital and engineer disagree on release colour`() {
        // SAME wire data, INVERTED visual semantics.
        // Hospital release → Default (closed, unfavourable).
        // Engineer release → Success (closed, favourable).
        // Pin so a refactor that unified them would surface here.
        val (hosText, hosKind) = hospitalDisputePillTextAndKind("resolved", "release")
        val (engText, engKind) = engineerDisputePillTextAndKind("resolved", "release")
        assertNotEquals(hosText, engText)
        assertNotEquals(hosKind, engKind)
    }

    @Test fun `cross-surface invariant — hospital and engineer disagree on refund colour`() {
        // Refund is favourable for hospital (Success) and
        // unfavourable for engineer (Warn).
        val (hosText, hosKind) = hospitalDisputePillTextAndKind("resolved", "refund")
        val (engText, engKind) = engineerDisputePillTextAndKind("resolved", "refund")
        assertNotEquals(hosText, engText)
        assertNotEquals(hosKind, engKind)
        assertEquals(PillKind.Success, hosKind)
        assertEquals(PillKind.Warn, engKind)
    }

    // ---- hospitalDisputeRowTitle -------------------------------------

    @Test fun `server jobNumber wins when present`() {
        assertEquals(
            "RPR-2026-00007",
            hospitalDisputeRowTitle("RPR-2026-00007", "abcdefghijkl"),
        )
    }

    @Test fun `null jobNumber falls back to RPR plus 6-char id prefix`() {
        assertEquals(
            "RPR-abcdef",
            hospitalDisputeRowTitle(null, "abcdefghijkl"),
        )
    }

    // ---- hospitalDisputeAmountAndEngineerLine ------------------------

    @Test fun `amount renders with rupee formatting and middle dot before engineer`() {
        val line = hospitalDisputeAmountAndEngineerLine(10_000.0, "Asha Rao")
        assertTrue(line.contains(" · "))
        assertTrue(line.endsWith(" · Asha Rao"))
    }

    @Test fun `null engineer falls back to Engineer role label`() {
        val line = hospitalDisputeAmountAndEngineerLine(10_000.0, null)
        assertTrue(line.endsWith(" · Engineer"))
    }

    @Test fun `blank engineer folds to Engineer role label`() {
        val line = hospitalDisputeAmountAndEngineerLine(10_000.0, "   ")
        assertTrue(line.endsWith(" · Engineer"))
    }
}
