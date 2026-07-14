package com.equipseva.app.core.data.referrals

import com.equipseva.app.core.util.formatRupees

/**
 * Roll-up of a referrer's [EngineerReferralRepository.MyReferral] rows.
 * Lives in core/data (with the repo) because it's shared by the referrals
 * cockpit (features/engineer) and the Earnings surface (features/earnings).
 *
 *  - [totalReferred]  every row, including revoked (they still referred them)
 *  - [paidCount] / [earnedRupees]  bounties actually paid out
 *  - [pendingCount] / [queuedRupees]  eligible-but-unpaid; queued rupees only
 *    count rows with an actual queued payout row (an eligible row without a
 *    payout row yet contributes to pendingCount but 0 to queuedRupees)
 *
 * Revoked rows are excluded from every money/pending tally.
 */
data class ReferralSummary(
    val totalReferred: Int = 0,
    val paidCount: Int = 0,
    val earnedRupees: Double = 0.0,
    val pendingCount: Int = 0,
    val queuedRupees: Double = 0.0,
)

internal fun referralSummary(
    referrals: List<EngineerReferralRepository.MyReferral>,
): ReferralSummary {
    var paidCount = 0
    var earned = 0.0
    var pending = 0
    var queued = 0.0
    for (r in referrals) {
        if (r.bountyRevoked) continue
        when {
            r.payoutStatus == "paid" -> {
                paidCount++
                earned += r.bountyAmountRupees
            }
            r.payoutStatus == "queued" -> {
                pending++
                queued += r.bountyAmountRupees
            }
            r.bountyEligible -> pending++ // eligible, payout row not minted yet
        }
    }
    return ReferralSummary(
        totalReferred = referrals.size,
        paidCount = paidCount,
        earnedRupees = earned,
        pendingCount = pending,
        queuedRupees = queued,
    )
}

/**
 * Subtitle for the Earnings-screen referral row. [summary] is null while
 * the slice is loading or after a fetch failure — both fall back to the
 * cold-start CTA so the row still invites referrals. Note [formatRupees]
 * already prepends the ₹ glyph, so callers must NOT add their own.
 */
internal fun referralEarningsRowSubtitle(summary: ReferralSummary?): String {
    val s = summary ?: return REFERRAL_ROW_CTA
    return when {
        s.totalReferred == 0 -> REFERRAL_ROW_CTA
        s.paidCount > 0 -> "${formatRupees(s.earnedRupees)} earned · ${s.totalReferred} referred"
        else -> "${s.totalReferred} referred · bounty pays after their first job"
    }
}

private const val REFERRAL_ROW_CTA =
    "Refer engineers — you earn ₹2,000 for each one's first paid job"
