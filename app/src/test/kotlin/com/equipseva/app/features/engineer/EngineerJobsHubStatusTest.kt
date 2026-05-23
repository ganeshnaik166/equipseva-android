package com.equipseva.app.features.engineer

import com.equipseva.app.core.data.engineers.VerificationStatus
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the EngineerJobsHub's VerificationStatus → Status routing.
 * Critical because the hub tiles (Available jobs, My bids, Active
 * work, Earnings) are gated on this status; a regression would
 * silently lock out a verified engineer or expose tiles to a
 * pending engineer.
 *
 * The null-engineer case is intentional — a user with no engineer
 * row at all (just signed up, not started KYC yet) lands on the
 * onboarding hero, not locked tiles.
 */
class EngineerJobsHubStatusTest {

    private fun mapStatus(v: VerificationStatus?) =
        EngineerJobsHubViewModel.hubStatusFor(v)

    @Test fun `verified engineer unlocks the Verified hub status`() {
        assertEquals(
            EngineerJobsHubViewModel.Status.Verified,
            mapStatus(VerificationStatus.Verified),
        )
    }

    @Test fun `pending engineer maps to Pending status`() {
        assertEquals(
            EngineerJobsHubViewModel.Status.Pending,
            mapStatus(VerificationStatus.Pending),
        )
    }

    @Test fun `rejected engineer maps to Rejected status`() {
        assertEquals(
            EngineerJobsHubViewModel.Status.Rejected,
            mapStatus(VerificationStatus.Rejected),
        )
    }

    @Test fun `null engineer (no row yet) maps to NotEngineer status`() {
        // Important: a user with no engineer row → onboarding hero.
        // Not locked tiles, not "Pending" (which would be confusing
        // for someone who never started KYC).
        assertEquals(
            EngineerJobsHubViewModel.Status.NotEngineer,
            mapStatus(null),
        )
    }

    @Test fun `every VerificationStatus entry has a hub status mapping`() {
        // Defensive — if a new VerificationStatus entry lands (e.g.
        // "Suspended"), the when{} above MUST grow a branch or the
        // hub will crash. Exhaustively iterate so the regression
        // surfaces.
        VerificationStatus.entries.forEach { v ->
            // Calling mapStatus(v) must not throw; if a future entry
            // lacks a branch the compiler would already complain.
            mapStatus(v)
        }
    }
}
