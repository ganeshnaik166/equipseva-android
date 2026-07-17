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

    /* --- round 437 fix #5: released + downstream payout failed --- */

    @Test fun `released with payout failed downgrades label to pending retry`() {
        val copy = escrowStatusCardCopy(row("released"), isHospital = true, payoutFailed = true)
        // Must NOT read "Released to engineer" — that would contradict
        // the EngineerPayoutStatusCard right below saying the bank
        // transfer didn't go through.
        assertEquals("Funds released — payout pending retry", copy.label)
        assertTrue(copy.subtitle.contains("bank transfer didn't go through"))
    }

    @Test fun `released with payout failed reads same both sides`() {
        // The downgrade copy is identical for hospital + engineer
        // because both sides need to know the money's stuck.
        val hospital = escrowStatusCardCopy(row("released"), isHospital = true, payoutFailed = true)
        val engineer = escrowStatusCardCopy(row("released"), isHospital = false, payoutFailed = true)
        assertEquals(hospital.label, engineer.label)
        assertEquals(hospital.subtitle, engineer.subtitle)
    }

    @Test fun `released with payout NOT failed still reads role-aware`() {
        val hospital = escrowStatusCardCopy(row("released"), isHospital = true, payoutFailed = false)
        val engineer = escrowStatusCardCopy(row("released"), isHospital = false, payoutFailed = false)
        assertEquals("Released to engineer", hospital.label)
        assertEquals("Released to you", engineer.label)
    }

    @Test fun `held with payoutFailed=true ignores the flag (only released downgrades)`() {
        // The downgrade only applies when escrow is released AND
        // downstream payout failed. For other escrow states the flag
        // is a no-op because no payout exists yet.
        val copy = escrowStatusCardCopy(row("held"), isHospital = true, payoutFailed = true)
        assertEquals("Funds in escrow", copy.label)
    }

    /* --- r1498: pending + held are role-aware like released ------------ */

    @Test fun `pending as engineer never instructs the viewer to pay`() {
        // Found live on the assigned-engineer view of RPR-00040: the old
        // single copy said "Pay ₹2,500 into escrow to release the
        // engineer" — payer-imperative addressed to the wrong party,
        // third-person about the viewer.
        val copy = escrowStatusCardCopy(row("pending"), isHospital = false)
        assertEquals("Awaiting payment", copy.label)
        assertTrue("got: ${copy.subtitle}", copy.subtitle.contains("Waiting for the hospital"))
        assertTrue(copy.subtitle.contains("₹2,500"))
        assertTrue("engineer must not be told to pay", !copy.subtitle.startsWith("Pay "))
        assertTrue("no third-person viewer reference", !copy.subtitle.contains("the engineer to start"))
    }

    @Test fun `pending as hospital still instructs the hospital to pay`() {
        val copy = escrowStatusCardCopy(row("pending"), isHospital = true)
        assertTrue("got: ${copy.subtitle}", copy.subtitle.startsWith("Pay "))
    }

    @Test fun `held as engineer reads auto-released to you, keeping the 48h promise`() {
        val copy = escrowStatusCardCopy(row("held"), isHospital = false)
        assertEquals("Funds in escrow", copy.label)
        assertTrue(copy.subtitle.contains("48h"))
        assertTrue(copy.subtitle.contains("to you"))
        assertTrue("no third-person on own view", !copy.subtitle.contains("to engineer"))
    }
}
