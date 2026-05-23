package com.equipseva.app.features.repair

import com.equipseva.app.core.data.escrow.RepairJobEscrowRepository
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the EscrowStatusCard label + subtitle copy. Critical regions:
 *
 *   * "Released" state branches on isHospital — engineer reads
 *     "Released to you", hospital reads "Released to engineer".
 *     A regression that dropped the role-aware branch would surface
 *     third-person "to engineer" copy on the engineer's view.
 *   * Held state promises 48h auto-release explicitly — pin the
 *     UX promise so a refactor doesn't quietly drop it.
 *   * Unknown future status surfaces literally ("Escrow xyz") so
 *     a stale server-side state doesn't render blank.
 *   * Rupee amounts pass through formatRupees (Indian lakh grouping).
 */
class EscrowStatusCardCopyTest {

    private fun row(
        status: String,
        amount: Double = 2500.0,
    ) = RepairJobEscrowRepository.EscrowRow(
        id = "e1",
        status = status,
        amountRupees = amount,
    )

    @Test fun `pending status shows Awaiting payment with rupee amount`() {
        val copy = escrowStatusCardCopy(row("pending"), isHospital = true)
        assertEquals("Awaiting payment", copy.label)
        assertTrue(copy.subtitle.contains("₹2,500"))
        assertTrue(copy.subtitle.contains("escrow"))
    }

    @Test fun `held status shows Funds in escrow with 48h auto-release callout`() {
        val copy = escrowStatusCardCopy(row("held"), isHospital = true)
        assertEquals("Funds in escrow", copy.label)
        // Pin the 48h promise — load-bearing UX commitment.
        assertTrue(copy.subtitle.contains("48h"))
        assertTrue(copy.subtitle.contains("Auto-released"))
    }

    @Test fun `in_dispute status shows neutral Funds-paused copy`() {
        val copy = escrowStatusCardCopy(row("in_dispute"), isHospital = true)
        assertEquals("Dispute open", copy.label)
        assertTrue(copy.subtitle.contains("paused"))
    }

    @Test fun `released to hospital shows third-person engineer copy`() {
        val copy = escrowStatusCardCopy(row("released"), isHospital = true)
        assertEquals("Released to engineer", copy.label)
        assertTrue(copy.subtitle.contains("engineer's bank account"))
    }

    @Test fun `released to engineer shows first-person you copy`() {
        // Critical role-aware branch — pin so engineer doesn't see
        // jarring "Released to engineer" on their own view.
        val copy = escrowStatusCardCopy(row("released"), isHospital = false)
        assertEquals("Released to you", copy.label)
        assertTrue(copy.subtitle.contains("your bank account"))
    }

    @Test fun `refunded status shows neutral Refunded line`() {
        val copy = escrowStatusCardCopy(row("refunded", amount = 1500.0), isHospital = true)
        assertEquals("Refunded", copy.label)
        assertTrue(copy.subtitle.contains("₹1,500"))
        assertTrue(copy.subtitle.contains("refunded"))
    }

    @Test fun `unknown status surfaces literally as Escrow status`() {
        // Forward-compat — pin so a future server-side state doesn't
        // render blank on older clients.
        val copy = escrowStatusCardCopy(row("future_state"), isHospital = true)
        assertEquals("Escrow future_state", copy.label)
        assertEquals("", copy.subtitle)
    }

    @Test fun `large lakh amounts use Indian grouping in subtitle`() {
        val copy = escrowStatusCardCopy(row("held", amount = 100000.0), isHospital = true)
        assertTrue(copy.subtitle.contains("₹1,00,000"))
    }

    @Test fun `held subtitle promises engineer not hospital (auto-release direction)`() {
        // The auto-release goes to the engineer (held → released to
        // engineer's bank). Pin the direction so a refactor doesn't
        // accidentally swap.
        val copy = escrowStatusCardCopy(row("held"), isHospital = true)
        assertTrue(copy.subtitle.contains("to engineer"))
    }
}
