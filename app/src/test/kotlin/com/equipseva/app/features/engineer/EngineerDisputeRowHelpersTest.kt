package com.equipseva.app.features.engineer

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the three pure helpers behind the engineer's My-Disputes row.
 *
 * Critical cross-surface invariant: the role-aware copy. The engineer
 * sees "Released to you" / "Refunded to hospital"; the hospital sees
 * the inverse ("Released to engineer" / "Refunded to you"). A
 * refactor that unified them would leak third-person grammar onto
 * the engineer's own row.
 */
class EngineerDisputeRowHelpersTest {

    // ---- engineerDisputePillTextAndKind ------------------------------

    @Test fun `in_dispute status wins regardless of outcome — Under review + Danger`() {
        // Critical pin — status takes priority over outcome. During
        // the brief resolution window, the server may have set
        // outcome before flipping status off in_dispute; the row
        // should still read "Under review" until status clears.
        assertEquals(
            "Under review" to PillKind.Danger,
            engineerDisputePillTextAndKind("in_dispute", null),
        )
        assertEquals(
            "Under review" to PillKind.Danger,
            engineerDisputePillTextAndKind("in_dispute", "release"),
        )
        assertEquals(
            "Under review" to PillKind.Danger,
            engineerDisputePillTextAndKind("in_dispute", "refund"),
        )
    }

    @Test fun `release outcome on non-in_dispute status reads Released to you + Success`() {
        // Critical pin — "you", not "to engineer". This is the
        // engineer-facing role-aware string.
        assertEquals(
            "Released to you" to PillKind.Success,
            engineerDisputePillTextAndKind("resolved", "release"),
        )
    }

    @Test fun `refund outcome on non-in_dispute status reads Refunded to hospital + Warn`() {
        // Refund is the bad outcome for the engineer — pin Warn
        // (amber), not Danger and not Default.
        assertEquals(
            "Refunded to hospital" to PillKind.Warn,
            engineerDisputePillTextAndKind("resolved", "refund"),
        )
    }

    @Test fun `unknown status falls through to status capitalised + Default`() {
        assertEquals(
            "Pending" to PillKind.Default,
            engineerDisputePillTextAndKind("pending", null),
        )
        assertEquals(
            "Held" to PillKind.Default,
            engineerDisputePillTextAndKind("held", null),
        )
    }

    @Test fun `unknown outcome on non-in_dispute status falls through to status default`() {
        assertEquals(
            "Resolved" to PillKind.Default,
            engineerDisputePillTextAndKind("resolved", null),
        )
        assertEquals(
            "Resolved" to PillKind.Default,
            engineerDisputePillTextAndKind("resolved", "some_future_outcome"),
        )
    }

    @Test fun `case-sensitive — In_dispute capital I falls through to default`() {
        // Pin exact-match on the wire string.
        val (text, kind) = engineerDisputePillTextAndKind("In_dispute", null)
        assertEquals("In_dispute", text)
        assertEquals(PillKind.Default, kind)
    }

    // ---- engineerDisputeRowTitle -------------------------------------

    @Test fun `server jobNumber wins when present`() {
        assertEquals(
            "RPR-2026-00007",
            engineerDisputeRowTitle("RPR-2026-00007", "abcdefghijkl"),
        )
    }

    @Test fun `null jobNumber falls back to RPR plus 6-char id prefix`() {
        assertEquals(
            "RPR-abcdef",
            engineerDisputeRowTitle(null, "abcdefghijkl"),
        )
    }

    // ---- engineerDisputeAmountAndHospitalLine ------------------------

    @Test fun `amount renders with rupee formatting and middle dot before hospital`() {
        val line = engineerDisputeAmountAndHospitalLine(10_000.0, "Apollo Hyderabad")
        assertTrue(line.contains(" · "))
        assertTrue(line.endsWith(" · Apollo Hyderabad"))
    }

    @Test fun `null hospital falls back to Hospital role label`() {
        val line = engineerDisputeAmountAndHospitalLine(10_000.0, null)
        assertTrue(line.endsWith(" · Hospital"))
    }

    @Test fun `blank hospital folds to Hospital role label`() {
        val line = engineerDisputeAmountAndHospitalLine(10_000.0, "   ")
        assertTrue(line.endsWith(" · Hospital"))
    }

    @Test fun `middle dot is U+00B7 not ASCII period`() {
        val line = engineerDisputeAmountAndHospitalLine(1.0, "X")
        assertTrue(line.contains('·'))
    }
}
