package com.equipseva.app.features.kyc

import com.equipseva.app.core.data.engineers.VerificationStatus
import org.junit.Assert.assertEquals
import org.junit.Test

class KycScreenSubtitleTest {

    @Test fun `Verified status returns Verified short-circuit (no wizard counter)`() {
        // Critical pin — Verified must NOT show "Step N of M".
        // The previous behaviour surfaced "Step 1 of 2" alongside a
        // fully-checked stepper which read as a contradiction.
        assertEquals(
            "Verified",
            kycScreenSubtitle(VerificationStatus.Verified, currentStepOrdinal = 0, totalSteps = 2),
        )
    }

    @Test fun `Pending status shows Step N of M`() {
        assertEquals(
            "Step 1 of 2",
            kycScreenSubtitle(VerificationStatus.Pending, currentStepOrdinal = 0, totalSteps = 2),
        )
    }

    @Test fun `Rejected status shows Step N of M`() {
        assertEquals(
            "Step 2 of 2",
            kycScreenSubtitle(VerificationStatus.Rejected, currentStepOrdinal = 1, totalSteps = 2),
        )
    }

    @Test fun `null status shows Step N of M (defensive)`() {
        // Defensive — Verified is the only short-circuit; everything
        // else falls through.
        assertEquals(
            "Step 1 of 3",
            kycScreenSubtitle(null, currentStepOrdinal = 0, totalSteps = 3),
        )
    }

    @Test fun `step counter is 1-indexed (ordinal + 1)`() {
        // Critical pin — currentStepOrdinal is 0-indexed enum ordinal;
        // user-facing counter is 1-indexed. A refactor that surfaced
        // the raw ordinal would show "Step 0 of N" on the first step.
        assertEquals(
            "Step 1 of 5",
            kycScreenSubtitle(VerificationStatus.Pending, 0, 5),
        )
        assertEquals(
            "Step 3 of 5",
            kycScreenSubtitle(VerificationStatus.Pending, 2, 5),
        )
    }

    @Test fun `Verified literal preserved verbatim`() {
        // Pin "Verified" not "Approved" or "Done" — must match the
        // wire status displayName for consistency across surfaces.
        assertEquals("Verified", kycScreenSubtitle(VerificationStatus.Verified, 0, 2))
    }
}
