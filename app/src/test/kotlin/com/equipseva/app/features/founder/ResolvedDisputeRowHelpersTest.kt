package com.equipseva.app.features.founder

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the three pure helpers behind the founder's resolved-dispute
 * row. Critical surfaces include the "release" wire-string gate and
 * the parties-line ORDER (hospital→engineer here, opposite of the
 * parts-outlier queue's engineer→hospital).
 */
class ResolvedDisputeRowHelpersTest {

    // ---- resolvedDisputeRowTitle -------------------------------------

    @Test fun `server jobNumber wins when present`() {
        assertEquals(
            "RPR-2026-00031",
            resolvedDisputeRowTitle("RPR-2026-00031", "abcdefghijkl"),
        )
    }

    @Test fun `null jobNumber falls back to RPR plus 6-char id prefix`() {
        assertEquals(
            "RPR-abcdef",
            resolvedDisputeRowTitle(null, "abcdefghijkl"),
        )
    }

    @Test fun `take 6 not take 8 — pinned to keep founder lookup consistent`() {
        // Critical pin — the founder cross-references this prefix
        // with the escrow-dispute queue (which also uses 6). A drift
        // to 8 would silently break the search workflow.
        val title = resolvedDisputeRowTitle(null, "abcdefghijklmnop")
        assertEquals("RPR-abcdef", title)
        assertTrue(title.length == "RPR-".length + 6)
    }

    // ---- resolvedDisputeOutcomePillTextAndKind ----------------------

    @Test fun `release wire string maps to Released with Success`() {
        // Critical regression target — the wire CHECK constraint uses
        // exactly "release". A server-side rename would silently flip
        // every resolved row to Refunded/Warn.
        assertEquals(
            "Released" to PillKind.Success,
            resolvedDisputeOutcomePillTextAndKind("release"),
        )
    }

    @Test fun `refund wire string maps to Refunded with Warn`() {
        assertEquals(
            "Refunded" to PillKind.Warn,
            resolvedDisputeOutcomePillTextAndKind("refund"),
        )
    }

    @Test fun `case-sensitive — Release with capital R falls through to Refunded`() {
        // Pin exact-match. The wire is lowercase; case-insensitive
        // matching would mask a server-side enum drift.
        assertEquals(
            "Refunded" to PillKind.Warn,
            resolvedDisputeOutcomePillTextAndKind("Release"),
        )
    }

    @Test fun `empty outcome falls through to Refunded`() {
        // Defensive — server CHECK forbids empty, but pin the
        // total-function shape so a refactor doesn't introduce a
        // null/empty branch.
        assertEquals(
            "Refunded" to PillKind.Warn,
            resolvedDisputeOutcomePillTextAndKind(""),
        )
    }

    @Test fun `unknown outcome falls through to Refunded (forward-compat)`() {
        assertEquals(
            "Refunded" to PillKind.Warn,
            resolvedDisputeOutcomePillTextAndKind("some_future_code"),
        )
    }

    // ---- resolvedDisputePartiesLine ----------------------------------

    @Test fun `parties line is hospital first, engineer second`() {
        // Critical pin — the INVERSE of partsOutlierPartiesLine. The
        // resolved-dispute row reads "hospital raised against engineer".
        // A refactor that unified them would silently swap subject/object.
        assertEquals(
            "Apollo Hyderabad → Asha Rao",
            resolvedDisputePartiesLine("Apollo Hyderabad", "Asha Rao"),
        )
    }

    @Test fun `null hospital falls back to Hospital role label`() {
        assertEquals(
            "Hospital → Asha Rao",
            resolvedDisputePartiesLine(null, "Asha Rao"),
        )
    }

    @Test fun `null engineer falls back to Engineer role label`() {
        assertEquals(
            "Apollo Hyderabad → Engineer",
            resolvedDisputePartiesLine("Apollo Hyderabad", null),
        )
    }

    @Test fun `both null fall back to role labels`() {
        assertEquals(
            "Hospital → Engineer",
            resolvedDisputePartiesLine(null, null),
        )
    }

    @Test fun `blanks on either side also fold to role labels`() {
        assertEquals(
            "Hospital → Engineer",
            resolvedDisputePartiesLine("   ", ""),
        )
    }

    @Test fun `arrow glyph is U+2192 not ASCII pointer`() {
        val line = resolvedDisputePartiesLine("A", "B")
        assertTrue(line.contains('→'))
        assertEquals(false, line.contains("->"))
    }
}
