package com.equipseva.app.features.profile

import com.equipseva.app.core.data.engineers.VerificationStatus
import com.equipseva.app.designsystem.components.StatusTone
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the engineer Profile "Verification (KYC)" row chip label +
 * tone. Two regions worth defending:
 *
 *   1) The Draft-vs-In-review split for Pending state. Server-side
 *      both are a single `pending` bucket, but the client splits
 *      based on whether the engineer has uploaded the three required
 *      docs (kycSubmitted). Pin so a regression doesn't collapse
 *      them — "In review" is the correct affordance after submit;
 *      "Draft" is wrong if the docs landed.
 *   2) Null engineer status → "Start" with Warn tone — drives the
 *      pre-KYC engineer who hasn't opened the flow at all to start.
 */
class KycRowLabelAndToneTest {

    @Test fun `null status maps to Start with Warn tone (pre-KYC)`() {
        val (label, tone) = kycRowLabelAndTone(
            engineerStatus = null,
            engineerKycSubmitted = false,
        )
        assertEquals("Start", label)
        assertEquals(StatusTone.Warn, tone)
    }

    @Test fun `null status ignores kycSubmitted flag (no engineer row yet means no docs)`() {
        // Defensive — kycSubmitted=true with status=null shouldn't
        // happen at runtime (no engineer row → no doc paths), but
        // the helper must not crash. Pin so a regression doesn't
        // produce an inconsistent "In review" before the engineer
        // row exists.
        val (label, tone) = kycRowLabelAndTone(
            engineerStatus = null,
            engineerKycSubmitted = true,
        )
        assertEquals("Start", label)
        assertEquals(StatusTone.Warn, tone)
    }

    @Test fun `Pending + kycSubmitted false maps to Draft (Warn)`() {
        // Engineer opened the KYC flow but hasn't finished uploads.
        // Draft tone is Warn — they need to come back.
        val (label, tone) = kycRowLabelAndTone(
            engineerStatus = VerificationStatus.Pending,
            engineerKycSubmitted = false,
        )
        assertEquals("Draft", label)
        assertEquals(StatusTone.Warn, tone)
    }

    @Test fun `Pending + kycSubmitted true maps to In review (Info)`() {
        // Critical UX — once the three docs land server-side, the
        // chip flips from Draft (Warn) to "In review" (Info). The
        // engineer has nothing left to do; admin owns the next step.
        val (label, tone) = kycRowLabelAndTone(
            engineerStatus = VerificationStatus.Pending,
            engineerKycSubmitted = true,
        )
        assertEquals("In review", label)
        assertEquals(StatusTone.Info, tone)
    }

    @Test fun `Verified status maps to Verified with Success tone`() {
        val (label, tone) = kycRowLabelAndTone(
            engineerStatus = VerificationStatus.Verified,
            engineerKycSubmitted = true,
        )
        assertEquals("Verified", label)
        assertEquals(StatusTone.Success, tone)
    }

    @Test fun `Verified status is Success regardless of kycSubmitted flag`() {
        // Defensive — kycSubmitted should be true once verified, but
        // a transient race where it's false during refresh shouldn't
        // demote the chip back to Draft.
        val (label, tone) = kycRowLabelAndTone(
            engineerStatus = VerificationStatus.Verified,
            engineerKycSubmitted = false,
        )
        assertEquals("Verified", label)
        assertEquals(StatusTone.Success, tone)
    }

    @Test fun `Rejected status maps to Rejected with Danger tone`() {
        val (label, tone) = kycRowLabelAndTone(
            engineerStatus = VerificationStatus.Rejected,
            engineerKycSubmitted = true,
        )
        assertEquals("Rejected", label)
        assertEquals(StatusTone.Danger, tone)
    }
}
