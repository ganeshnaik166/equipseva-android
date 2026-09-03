package com.equipseva.app.features.profile

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the pure helpers behind [CommissionTierScreen] (round3772) —
 * the first Android client of the v21 `get_my_commission_tier` RPC.
 */
class CommissionTierHelpersTest {

    private fun tier(
        completed12m: Int = 0,
        currentRate: Double = 0.07,
        nextTierRate: Double? = 0.05,
        jobsToNextTier: Int = 10,
    ) = CommissionTierRepository.CommissionTier(
        completed12m = completed12m,
        currentRate = currentRate,
        nextTierRate = nextTierRate,
        jobsToNextTier = jobsToNextTier,
    )

    @Test fun `7 percent rate renders as whole number, not a float artifact`() {
        assertEquals("7%", commissionRatePercentLabel(0.07))
    }

    @Test fun `5 and 3 percent tiers also render clean`() {
        assertEquals("5%", commissionRatePercentLabel(0.05))
        assertEquals("3%", commissionRatePercentLabel(0.03))
    }

    @Test fun `progress text at the default tier names the job count and next rate`() {
        assertEquals(
            "10 more completed jobs unlocks 5% commission",
            commissionTierProgressText(tier(currentRate = 0.07, nextTierRate = 0.05, jobsToNextTier = 10)),
        )
    }

    @Test fun `progress text singularizes 1 remaining job`() {
        assertEquals(
            "1 more completed job unlocks 5% commission",
            commissionTierProgressText(tier(currentRate = 0.07, nextTierRate = 0.05, jobsToNextTier = 1)),
        )
    }

    @Test fun `top tier (next_tier_rate null) reads as already-best, not a broken countdown`() {
        assertEquals(
            "You're at the best tier (3%)",
            commissionTierProgressText(tier(currentRate = 0.03, nextTierRate = null, jobsToNextTier = 0)),
        )
    }
}
