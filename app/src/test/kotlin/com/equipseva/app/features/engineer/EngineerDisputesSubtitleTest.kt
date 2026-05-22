package com.equipseva.app.features.engineer

import com.equipseva.app.core.data.escrow.RepairJobEscrowRepository
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins the engineer-disputes screen subtitle. Distinct from the
 * hospital variant — engineers care about "released to you" (outcome
 * == "release"), not the broader "resolved" bucket which also covers
 * refunds AGAINST them.
 *
 * Pinned regions:
 *   * Empty list → null (no phantom subtitle on cold-load).
 *   * "released to you" counts outcome == "release" (NOT every
 *     non-in_dispute status). A refunded dispute is "resolved" on
 *     the hospital side but is NOT a win for the engineer.
 *   * Strict in_dispute / release wire-string matching.
 */
class EngineerDisputesSubtitleTest {

    private fun row(
        status: String,
        outcome: String? = null,
        id: String = "e1",
    ) = RepairJobEscrowRepository.EngineerDisputeRow(
        escrowId = id,
        repairJobId = "j-$id",
        amountRupees = 2500.0,
        status = status,
        outcome = outcome,
    )

    @Test fun `empty rows yields null`() {
        assertNull(engineerDisputesSubtitle(emptyList()))
    }

    @Test fun `single in_dispute row yields one-open zero-won`() {
        val out = engineerDisputesSubtitle(listOf(row("in_dispute")))
        assertEquals("1 open · 0 released to you · last 12 months", out)
    }

    @Test fun `release outcome counts as won`() {
        val out = engineerDisputesSubtitle(
            listOf(row("released", outcome = "release")),
        )
        assertEquals("0 open · 1 released to you · last 12 months", out)
    }

    @Test fun `refund outcome does NOT count as won (released to engineer is the metric)`() {
        // A refunded escrow is "resolved" but the engineer LOST it —
        // critical that it doesn't count as a release-to-engineer.
        val out = engineerDisputesSubtitle(
            listOf(row("refunded", outcome = "refund")),
        )
        assertEquals("0 open · 0 released to you · last 12 months", out)
    }

    @Test fun `mixed list counts correctly`() {
        val out = engineerDisputesSubtitle(
            listOf(
                row("in_dispute", id = "a"),
                row("in_dispute", id = "b"),
                row("released", outcome = "release", id = "c"),
                row("refunded", outcome = "refund", id = "d"),
                row("released", outcome = "release", id = "e"),
            ),
        )
        assertEquals("2 open · 2 released to you · last 12 months", out)
    }

    @Test fun `null outcome on an in_dispute row counts as open only (no win)`() {
        // Open disputes haven't yet been decided — they MUST NOT
        // count as a win regardless of any default outcome.
        val out = engineerDisputesSubtitle(listOf(row("in_dispute", outcome = null)))
        assertEquals("1 open · 0 released to you · last 12 months", out)
    }

    @Test fun `case-sensitive outcome match (server wire format is lowercase)`() {
        // "Release" / "RELEASE" don't match — pin the strict contract.
        val out = engineerDisputesSubtitle(
            listOf(row("released", outcome = "RELEASE")),
        )
        assertEquals("0 open · 0 released to you · last 12 months", out)
    }
}
