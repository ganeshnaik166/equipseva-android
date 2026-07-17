package com.equipseva.app.core.data.referrals

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the referral-bounty roll-up (money logic: ₹2,000 per referral). Regions
 * to defend:
 *   1) Revoked rows are excluded from EVERY money/pending tally but still count
 *      toward totalReferred ("they still referred them").
 *   2) paid → paidCount + earnedRupees; queued → pendingCount + queuedRupees;
 *      eligible-but-no-payout-row-yet → pendingCount only (0 queuedRupees).
 *   3) The Earnings-row subtitle branches (loading/empty CTA, earned, pending).
 */
class ReferralSummaryTest {

    private fun ref(
        id: String = "r1",
        eligible: Boolean = false,
        revoked: Boolean = false,
        amount: Double = 2000.0,
        payoutStatus: String? = null,
    ) = EngineerReferralRepository.MyReferral(
        id = id,
        refereeUserId = "u-$id",
        bountyEligible = eligible,
        bountyRevoked = revoked,
        bountyAmountRupees = amount,
        payoutStatus = payoutStatus,
        createdAt = "2026-05-01T00:00:00Z",
    )

    @Test fun `empty list is all zeros`() {
        assertEquals(ReferralSummary(), referralSummary(emptyList()))
    }

    @Test fun `paid row adds to paidCount and earnedRupees`() {
        val s = referralSummary(listOf(ref(payoutStatus = "paid", eligible = true)))
        assertEquals(1, s.totalReferred)
        assertEquals(1, s.paidCount)
        assertEquals(2000.0, s.earnedRupees, 0.0)
        assertEquals(0, s.pendingCount)
        assertEquals(0.0, s.queuedRupees, 0.0)
    }

    @Test fun `queued row adds to pendingCount and queuedRupees`() {
        val s = referralSummary(listOf(ref(payoutStatus = "queued", eligible = true)))
        assertEquals(1, s.pendingCount)
        assertEquals(2000.0, s.queuedRupees, 0.0)
        assertEquals(0, s.paidCount)
        assertEquals(0.0, s.earnedRupees, 0.0)
    }

    @Test fun `eligible with no payout row yet is pending but contributes zero queued rupees`() {
        val s = referralSummary(listOf(ref(eligible = true, payoutStatus = null)))
        assertEquals(1, s.pendingCount)
        assertEquals(0.0, s.queuedRupees, 0.0)
    }

    @Test fun `not-yet-eligible row counts only toward totalReferred`() {
        val s = referralSummary(listOf(ref(eligible = false, payoutStatus = null)))
        assertEquals(1, s.totalReferred)
        assertEquals(0, s.pendingCount)
        assertEquals(0, s.paidCount)
    }

    @Test fun `revoked row is excluded from money and pending but still counted as referred`() {
        // Even a revoked+paid row must not add to earnings/paidCount.
        val s = referralSummary(listOf(ref(payoutStatus = "paid", eligible = true, revoked = true)))
        assertEquals(1, s.totalReferred)
        assertEquals(0, s.paidCount)
        assertEquals(0.0, s.earnedRupees, 0.0)
        assertEquals(0, s.pendingCount)
        assertEquals(0.0, s.queuedRupees, 0.0)
    }

    @Test fun `mixed list tallies each bucket correctly`() {
        val s = referralSummary(
            listOf(
                ref(id = "a", payoutStatus = "paid", eligible = true, amount = 2000.0),
                ref(id = "b", payoutStatus = "paid", eligible = true, amount = 2000.0),
                ref(id = "c", payoutStatus = "queued", eligible = true, amount = 2000.0),
                ref(id = "d", eligible = true, payoutStatus = null), // eligible, no payout row
                ref(id = "e", eligible = false, payoutStatus = null), // referred only
                ref(id = "f", payoutStatus = "paid", eligible = true, revoked = true), // revoked
            ),
        )
        assertEquals(6, s.totalReferred)
        assertEquals(2, s.paidCount)
        assertEquals(4000.0, s.earnedRupees, 0.0)
        assertEquals(2, s.pendingCount) // c (queued) + d (eligible)
        assertEquals(2000.0, s.queuedRupees, 0.0) // only c has a queued payout row
    }

    // ---- referralEarningsRowSubtitle ----------------------------------

    @Test fun `subtitle null summary shows the cold-start CTA`() {
        assertEquals(
            "Refer engineers — you earn ₹2,000 for each one's first paid job",
            referralEarningsRowSubtitle(null),
        )
    }

    @Test fun `subtitle zero referred shows the CTA`() {
        assertEquals(
            "Refer engineers — you earn ₹2,000 for each one's first paid job",
            referralEarningsRowSubtitle(ReferralSummary(totalReferred = 0)),
        )
    }

    @Test fun `subtitle with paid bounties shows earned and referred count`() {
        val s = ReferralSummary(totalReferred = 3, paidCount = 1, earnedRupees = 2000.0)
        assertEquals("₹2,000 earned · 3 referred", referralEarningsRowSubtitle(s))
    }

    @Test fun `subtitle referred-but-none-paid explains when the bounty pays`() {
        val s = ReferralSummary(totalReferred = 2, paidCount = 0)
        assertEquals("2 referred · bounty pays after their first job", referralEarningsRowSubtitle(s))
    }
}
