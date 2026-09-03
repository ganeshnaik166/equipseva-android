package com.equipseva.app.features.profile

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins [referralStatusLabelAndKind] behind [EngineerReferralScreen]
 * (round3777) — the first Android client of the round564 engineer
 * referral bounty backend (+ round568's audit-19 self-attribution
 * security patch).
 */
class EngineerReferralHelpersTest {

    private fun referral(
        bountyEligible: Boolean = false,
        bountyRevoked: Boolean = false,
        payoutStatus: String? = null,
    ) = EngineerReferralRepository.Referral(
        id = "r1",
        refereeUserId = "u1",
        refereeFirstCompletedAt = null,
        bountyEligible = bountyEligible,
        bountyRevoked = bountyRevoked,
        bountyRevokeReason = null,
        bountyAmountRupees = 2000.0,
        payoutStatus = payoutStatus,
        payoutUtr = null,
        createdAt = "2026-01-01T00:00:00Z",
    )

    @Test fun `revoked always wins regardless of eligible or payout state`() {
        assertEquals(
            "Revoked" to PillKind.Danger,
            referralStatusLabelAndKind(referral(bountyRevoked = true, bountyEligible = true, payoutStatus = "paid")),
        )
    }

    @Test fun `paid payout renders Success`() {
        assertEquals(
            "Paid" to PillKind.Success,
            referralStatusLabelAndKind(referral(bountyEligible = true, payoutStatus = "paid")),
        )
    }

    @Test fun `queued payout renders Info`() {
        assertEquals(
            "Queued for payout" to PillKind.Info,
            referralStatusLabelAndKind(referral(bountyEligible = true, payoutStatus = "queued")),
        )
    }

    @Test fun `eligible with no payout row yet still renders Success`() {
        assertEquals(
            "Eligible" to PillKind.Success,
            referralStatusLabelAndKind(referral(bountyEligible = true, payoutStatus = null)),
        )
    }

    @Test fun `not yet eligible, not revoked renders Pending`() {
        assertEquals(
            "Pending" to PillKind.Warn,
            referralStatusLabelAndKind(referral(bountyEligible = false, payoutStatus = null)),
        )
    }
}
