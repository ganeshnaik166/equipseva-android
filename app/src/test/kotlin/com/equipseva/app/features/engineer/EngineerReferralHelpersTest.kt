package com.equipseva.app.features.engineer

import com.equipseva.app.core.data.referrals.EngineerReferralRepository
import com.equipseva.app.core.data.referrals.referralCodeInputError
import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins for the r1387 engineer-referral helpers. These mirror the server
 * contract in round564_engineer_referral_bounty.sql: ₹2,000 default bounty,
 * a revoke flag that cancels the payout, and a LEFT-JOINed payout status
 * that is null until the daily cron mints the payout row.
 */
class EngineerReferralHelpersTest {

    private fun referral(
        id: String = "ref-1",
        referee: String = "0000000000000000000000000000abcd",
        eligible: Boolean = false,
        revoked: Boolean = false,
        revokeReason: String? = null,
        amount: Double = 2000.0,
        payoutStatus: String? = null,
        createdAt: String = "2026-07-01T09:30:00Z",
    ) = EngineerReferralRepository.MyReferral(
        id = id,
        refereeUserId = referee,
        refereeFirstCompletedAt = null,
        bountyEligible = eligible,
        bountyRevoked = revoked,
        bountyRevokeReason = revokeReason,
        bountyAmountRupees = amount,
        payoutStatus = payoutStatus,
        payoutUtr = null,
        createdAt = createdAt,
    )

    // ---- referralBountyPillTextAndKind --------------------------------

    @Test fun `paid payout reads Paid Success`() {
        assertEquals("Paid" to PillKind.Success, referralBountyPillTextAndKind(true, false, "paid"))
    }

    @Test fun `queued payout reads Bounty queued Info`() {
        assertEquals(
            "Bounty queued" to PillKind.Info,
            referralBountyPillTextAndKind(true, false, "queued"),
        )
    }

    @Test fun `eligible without a payout row reads Eligible Info`() {
        assertEquals("Eligible" to PillKind.Info, referralBountyPillTextAndKind(true, false, null))
    }

    @Test fun `not-yet-eligible reads Awaiting first job Neutral`() {
        assertEquals(
            "Awaiting first job" to PillKind.Neutral,
            referralBountyPillTextAndKind(false, false, null),
        )
    }

    @Test fun `revoked wins over a queued payout`() {
        // A revoked bounty's payout is cancelled server-side; it must never
        // read as queued/paid even if the joined row lags.
        assertEquals(
            "Revoked" to PillKind.Danger,
            referralBountyPillTextAndKind(true, true, "queued"),
        )
    }

    @Test fun `revoked wins over a paid payout`() {
        assertEquals(
            "Revoked" to PillKind.Danger,
            referralBountyPillTextAndKind(true, true, "paid"),
        )
    }

    // ---- referralSummary ----------------------------------------------

    @Test fun `empty list summarises to all zeros`() {
        val s = referralSummary(emptyList())
        assertEquals(0, s.totalReferred)
        assertEquals(0, s.paidCount)
        assertEquals(0.0, s.earnedRupees, 0.0)
        assertEquals(0, s.pendingCount)
        assertEquals(0.0, s.queuedRupees, 0.0)
    }

    @Test fun `paid rows accrue earned rupees and paid count`() {
        val s = referralSummary(
            listOf(
                referral(id = "a", amount = 2000.0, eligible = true, payoutStatus = "paid"),
                referral(id = "b", amount = 2500.0, eligible = true, payoutStatus = "paid"),
            ),
        )
        assertEquals(2, s.totalReferred)
        assertEquals(2, s.paidCount)
        assertEquals(4500.0, s.earnedRupees, 0.0)
        assertEquals(0, s.pendingCount)
    }

    @Test fun `queued rows accrue queued rupees and pending count`() {
        val s = referralSummary(listOf(referral(amount = 2000.0, eligible = true, payoutStatus = "queued")))
        assertEquals(1, s.pendingCount)
        assertEquals(2000.0, s.queuedRupees, 0.0)
        assertEquals(0, s.paidCount)
        assertEquals(0.0, s.earnedRupees, 0.0)
    }

    @Test fun `eligible without payout row counts as pending but zero queued rupees`() {
        val s = referralSummary(listOf(referral(amount = 2000.0, eligible = true, payoutStatus = null)))
        assertEquals(1, s.pendingCount)
        assertEquals(0.0, s.queuedRupees, 0.0)
    }

    @Test fun `revoked row is counted in totalReferred but excluded from money and pending`() {
        val s = referralSummary(
            listOf(referral(amount = 2000.0, eligible = true, revoked = true, payoutStatus = "queued")),
        )
        assertEquals(1, s.totalReferred)
        assertEquals(0, s.pendingCount)
        assertEquals(0.0, s.queuedRupees, 0.0)
        assertEquals(0, s.paidCount)
        assertEquals(0.0, s.earnedRupees, 0.0)
    }

    // ---- refereeShortLabel --------------------------------------------

    @Test fun `short label uses last four id chars uppercased`() {
        assertEquals("Engineer ••2F3A", refereeShortLabel("0000000000000000000000000000-2f3a"))
    }

    @Test fun `short label mask glyph is U+2022 bullet`() {
        assertTrue(refereeShortLabel("abcd").contains("••"))
    }

    @Test fun `short label is defensive when id is shorter than four chars`() {
        assertEquals("Engineer ••AB", refereeShortLabel("ab"))
    }

    // ---- referralCodeInputError ---------------------------------------

    @Test fun `blank code has no error`() {
        assertNull(referralCodeInputError("", "me-123"))
        assertNull(referralCodeInputError("   ", "me-123"))
    }

    @Test fun `own code is flagged as self-referral case-insensitively`() {
        val err = referralCodeInputError("ME-123", "me-123")
        assertEquals("That's your own code — you can't refer yourself.", err)
    }

    @Test fun `a different code passes client validation`() {
        assertNull(referralCodeInputError("someone-else-999", "me-123"))
    }

    @Test fun `self-referral message uses an em-dash U+2014`() {
        // Pin the punctuation: the copy uses an em-dash (—), not a hyphen,
        // consistent with the rest of the app's inline strings.
        val err = referralCodeInputError("me-123", "me-123")!!
        assertTrue(err.contains("—"))
    }
}
