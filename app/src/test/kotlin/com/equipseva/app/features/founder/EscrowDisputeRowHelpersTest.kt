package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the two helpers behind the founder escrow-dispute row.
 *
 * Critical regions:
 *   * escrowDisputeRowTitle — jobNumber preferred, falls back to
 *     "RPR-" + first 6 chars of repairJobId. The 6-char prefix
 *     matches the tap-target identifier shown elsewhere, so a
 *     founder hunting cross-queue gets a consistent ID.
 *   * escrowDisputePartiesLine — both names default to generic
 *     ("Hospital", "Engineer") with the U+2192 arrow separator.
 *     Pin so an ASCII "->" doesn't slip past and fragment the
 *     visual.
 */
class EscrowDisputeRowHelpersTest {

    // ---- escrowDisputeRowTitle ----

    @Test fun `server-provided jobNumber preferred over fallback`() {
        assertEquals(
            "RPR-00027",
            escrowDisputeRowTitle(jobNumber = "RPR-00027", repairJobId = "abc-123-456-789"),
        )
    }

    @Test fun `null jobNumber falls back to RPR-prefixed first 6 chars of id`() {
        assertEquals(
            "RPR-abc123",
            escrowDisputeRowTitle(jobNumber = null, repairJobId = "abc123-def-456"),
        )
    }

    @Test fun `fallback takes exactly 6 chars (not more, not fewer)`() {
        // Pin so a refactor that switched to .take(8) / .take(4)
        // doesn't drift from the cross-queue identifier convention.
        val out = escrowDisputeRowTitle(
            jobNumber = null,
            repairJobId = "1234567890",
        )
        assertEquals("RPR-123456", out)
        assertEquals(10, out.length)
    }

    @Test fun `short repairJobId in fallback takes whatever's there`() {
        // < 6 char id — defensive; take(6) returns shorter string.
        val out = escrowDisputeRowTitle(jobNumber = null, repairJobId = "abc")
        assertEquals("RPR-abc", out)
    }

    // ---- escrowDisputePartiesLine ----

    @Test fun `both names present render with arrow separator`() {
        assertEquals(
            "Apollo → Ravi Kumar",
            escrowDisputePartiesLine("Apollo", "Ravi Kumar"),
        )
    }

    @Test fun `null hospital folds to Hospital`() {
        assertEquals(
            "Hospital → Ravi Kumar",
            escrowDisputePartiesLine(null, "Ravi Kumar"),
        )
    }

    @Test fun `null engineer folds to Engineer`() {
        assertEquals(
            "Apollo → Engineer",
            escrowDisputePartiesLine("Apollo", null),
        )
    }

    @Test fun `both null fold to generic Hospital → Engineer`() {
        assertEquals(
            "Hospital → Engineer",
            escrowDisputePartiesLine(null, null),
        )
    }

    @Test fun `blank names treated the same as null`() {
        assertEquals(
            "Hospital → Engineer",
            escrowDisputePartiesLine("  ", "   "),
        )
    }

    @Test fun `arrow glyph is U+2192 (not ASCII)`() {
        val out = escrowDisputePartiesLine("A", "B")
        assertEquals(true, out.contains('→'))
        assertEquals(false, out.contains("->"))
    }
}
