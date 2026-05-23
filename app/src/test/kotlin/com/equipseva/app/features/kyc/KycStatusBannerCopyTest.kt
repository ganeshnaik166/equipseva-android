package com.equipseva.app.features.kyc

import com.equipseva.app.core.data.engineers.VerificationStatus
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the KYC status-banner copy across the four states:
 *
 *   * Verified — "You can accept jobs."
 *   * Rejected — "Re-upload the flagged documents."
 *   * Pending + submitted=true — "Typically reviewed within 4–24 hours."
 *   * Pending + submitted=false — "Complete every step to submit for review."
 *
 * The Pending split is the critical region: the same wire status
 * means two very different things on-screen depending on whether the
 * engineer has actually uploaded all three required docs. A
 * regression that collapsed the split would tell a mid-flight
 * engineer they're "submitted for review" before they actually were.
 */
class KycStatusBannerCopyTest {

    @Test fun `Verified shows accept-jobs copy`() {
        val copy = kycStatusBannerCopy(VerificationStatus.Verified, submitted = true)
        assertEquals("Verified", copy.label)
        assertEquals("You can accept jobs.", copy.subtitle)
    }

    @Test fun `Verified ignores submitted flag (terminal state)`() {
        // Defensive — Verified is terminal; submitted should be true
        // by definition (you can't be verified without submitting),
        // but pin so the copy doesn't drift.
        val a = kycStatusBannerCopy(VerificationStatus.Verified, submitted = true)
        val b = kycStatusBannerCopy(VerificationStatus.Verified, submitted = false)
        assertEquals(a, b)
    }

    @Test fun `Rejected shows re-upload copy`() {
        val copy = kycStatusBannerCopy(VerificationStatus.Rejected, submitted = true)
        assertEquals("Rejected", copy.label)
        assertEquals("Re-upload the flagged documents.", copy.subtitle)
    }

    @Test fun `Rejected ignores submitted flag (terminal-ish state)`() {
        val a = kycStatusBannerCopy(VerificationStatus.Rejected, submitted = true)
        val b = kycStatusBannerCopy(VerificationStatus.Rejected, submitted = false)
        assertEquals(a, b)
    }

    @Test fun `Pending plus submitted shows the 4-24h review copy`() {
        val copy = kycStatusBannerCopy(VerificationStatus.Pending, submitted = true)
        assertEquals("Submitted for review", copy.label)
        assertEquals("Typically reviewed within 4–24 hours.", copy.subtitle)
    }

    @Test fun `Pending without submission shows the in-progress copy`() {
        // Critical split — same wire status, different UX.
        val copy = kycStatusBannerCopy(VerificationStatus.Pending, submitted = false)
        assertEquals("In progress", copy.label)
        assertEquals("Complete every step to submit for review.", copy.subtitle)
    }

    @Test fun `Pending split copy differs across the submitted flag`() {
        val submitted = kycStatusBannerCopy(VerificationStatus.Pending, submitted = true)
        val midFlight = kycStatusBannerCopy(VerificationStatus.Pending, submitted = false)
        // Pin so a future collapse to a single copy is intentional.
        assertEquals(false, submitted == midFlight)
    }

    @Test fun `subtitle uses unicode en-dash for the 4-24 hour range`() {
        // U+2013 EN DASH, not ASCII "-". Pin so a future code review
        // that "fixed" the dash to ASCII surfaces.
        val copy = kycStatusBannerCopy(VerificationStatus.Pending, submitted = true)
        assertEquals(true, copy.subtitle.contains('–'))
        assertEquals(false, copy.subtitle.contains("4-24"))
    }
}
