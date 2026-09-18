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

    @Test fun `a fetch failure never downgrades a status we already know`() {
        // Mapping every failure to NotEngineer told a VERIFIED engineer to
        // "become a verified engineer" and hid every tile — and the hub
        // re-fetches on each resume, so a flaky connection repeated it and
        // invited a pointless second KYC submission.
        listOf(
            EngineerJobsHubViewModel.Status.Verified,
            EngineerJobsHubViewModel.Status.Pending,
            EngineerJobsHubViewModel.Status.Rejected,
            EngineerJobsHubViewModel.Status.NotEngineer,
        ).forEach { known ->
            assertEquals(known, EngineerJobsHubViewModel.hubStatusOnFetchFailure(known))
        }
    }

    @Test fun `a fetch failure with nothing loaded yet is a retryable error`() {
        // NotSignedIn belongs here, not above: it says nothing about
        // verification. It is the state the collector holds while signed out,
        // and keeping it through the first post-sign-in fetch failure left a
        // signed-in engineer looking at the "Sign in" hero with no way back.
        listOf(
            EngineerJobsHubViewModel.Status.Loading,
            EngineerJobsHubViewModel.Status.NotSignedIn,
        ).forEach { nothingLoaded ->
            assertEquals(
                EngineerJobsHubViewModel.Status.Error,
                EngineerJobsHubViewModel.hubStatusOnFetchFailure(nothingLoaded),
            )
        }
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
