package com.equipseva.app.features.kyc

import com.equipseva.app.core.data.engineers.VerificationStatus
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the three-step timeline branches the KYC Verification screen
 * (PR #169) shows the engineer. Every transition is user-visible and a
 * silent change to the subtitle copy would land in a release. Treat the
 * strings as part of the contract.
 */
class KycStatusTimelineRenderTest {

    @Test fun `pending without docs has step 1 active and the draft subtitle`() {
        val render = TimelineRender.from(VerificationStatus.Pending, submitted = false)
        assertEquals(StepState.Active, render.s1)
        assertEquals(StepState.Pending, render.s2)
        assertEquals(StepState.Pending, render.s3)
        assertEquals(
            "Upload documents and submit to start the review.",
            render.subtitle,
        )
    }

    @Test fun `pending with docs has step 1 done and step 2 active`() {
        val render = TimelineRender.from(VerificationStatus.Pending, submitted = true)
        assertEquals(StepState.Done, render.s1)
        assertEquals(StepState.Active, render.s2)
        assertEquals(StepState.Pending, render.s3)
        assertEquals(
            "Submitted. A reviewer is checking your documents.",
            render.subtitle,
        )
    }

    @Test fun `verified fills every step green`() {
        // submitted flag is ignored on terminal states — pin both.
        listOf(true, false).forEach { submitted ->
            val render = TimelineRender.from(VerificationStatus.Verified, submitted)
            assertEquals("submitted=$submitted", StepState.Done, render.s1)
            assertEquals("submitted=$submitted", StepState.Done, render.s2)
            assertEquals("submitted=$submitted", StepState.Done, render.s3)
            assertEquals(
                "submitted=$submitted",
                "Your verification is complete.",
                render.subtitle,
            )
        }
    }

    @Test fun `rejected renders step 2 with a red-X branch and re-upload CTA copy`() {
        // Reviewer must always have seen the submission to reject it, so
        // step 1 stays Done and the X lands on step 2 (review).
        listOf(true, false).forEach { submitted ->
            val render = TimelineRender.from(VerificationStatus.Rejected, submitted)
            assertEquals(StepState.Done, render.s1)
            assertEquals(StepState.Rejected, render.s2)
            assertEquals(StepState.Pending, render.s3)
            assertEquals(
                "Your documents were rejected. Re-upload to send it back for review.",
                render.subtitle,
            )
        }
    }
}
