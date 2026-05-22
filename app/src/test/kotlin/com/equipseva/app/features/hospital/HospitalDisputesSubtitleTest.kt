package com.equipseva.app.features.hospital

import com.equipseva.app.core.data.escrow.RepairJobEscrowRepository
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins the hospital-disputes screen subtitle resolver. Three regions:
 *
 *   * Empty rows → null (top-bar hides the line on cold-load instead
 *     of rendering a phantom "0 open · 0 resolved").
 *   * `in_dispute` is the only "open" status — anything else
 *     (released / refunded / resolved / future) counts as resolved.
 *   * Copy uses the unicode middle-dot "·" (U+00B7), not ASCII "•"
 *     and not the surrounded-by-spaces ASCII "*". Pin so a Compose
 *     refactor doesn't drift typography.
 */
class HospitalDisputesSubtitleTest {

    private fun row(
        status: String,
        id: String = "e1",
    ) = RepairJobEscrowRepository.HospitalDisputeRow(
        escrowId = id,
        repairJobId = "j-$id",
        amountRupees = 2500.0,
        status = status,
    )

    @Test fun `empty rows yields null (no phantom subtitle on cold-load)`() {
        assertNull(hospitalDisputesSubtitle(emptyList()))
    }

    @Test fun `single in_dispute row yields one-open zero-resolved`() {
        val out = hospitalDisputesSubtitle(listOf(row("in_dispute")))
        assertEquals("1 open · 0 resolved · last 12 months", out)
    }

    @Test fun `single resolved (released) row yields zero-open one-resolved`() {
        val out = hospitalDisputesSubtitle(listOf(row("released")))
        assertEquals("0 open · 1 resolved · last 12 months", out)
    }

    @Test fun `mixed list counts correctly`() {
        val out = hospitalDisputesSubtitle(
            listOf(
                row("in_dispute", "a"),
                row("in_dispute", "b"),
                row("released", "c"),
                row("refunded", "d"),
                row("resolved", "e"),
            ),
        )
        assertEquals("2 open · 3 resolved · last 12 months", out)
    }

    @Test fun `future status counts as resolved (everything not in_dispute)`() {
        // Forward-compat: a new server-side status surfaces as "resolved"
        // rather than disappearing. The hospital still sees it in the
        // list; the count just buckets right.
        val out = hospitalDisputesSubtitle(listOf(row("future_state")))
        assertEquals("0 open · 1 resolved · last 12 months", out)
    }

    @Test fun `case-sensitive match (server-side enum is lowercase)`() {
        // "IN_DISPUTE" (uppercase) does NOT match — pin so the wire
        // format stays strict.
        val out = hospitalDisputesSubtitle(listOf(row("IN_DISPUTE")))
        assertEquals("0 open · 1 resolved · last 12 months", out)
    }

    @Test fun `subtitle uses the middle-dot separator (U+00B7) not ASCII bullet`() {
        val out = hospitalDisputesSubtitle(listOf(row("in_dispute")))!!
        assertEquals(2, out.count { it == '·' })
        // Defense against an ASCII fallback.
        assertEquals(0, out.count { it == '*' })
        assertEquals(0, out.count { it == '•' })
    }
}
