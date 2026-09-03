package com.equipseva.app.features.profile

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the pure helpers behind [ProfileCompletenessScreen] (round3775)
 * — the first Android client of the round504 `engineer_profile_completeness`
 * RPC.
 */
class ProfileCompletenessHelpersTest {

    @Test fun `complete band renders Success + green`() {
        val v = profileCompletenessBandVisual("complete")
        assertEquals("Complete", v.label)
        assertEquals(PillKind.Success, v.kind)
    }

    @Test fun `partial band renders Warn`() {
        assertEquals(PillKind.Warn, profileCompletenessBandVisual("partial").kind)
    }

    @Test fun `incomplete band renders Danger`() {
        assertEquals(PillKind.Danger, profileCompletenessBandVisual("incomplete").kind)
    }

    @Test fun `unknown band falls back to Danger rather than crashing`() {
        val v = profileCompletenessBandVisual("mystery")
        assertEquals("Incomplete", v.label)
        assertEquals(PillKind.Danger, v.kind)
    }

    @Test fun `known missing-item codes map to readable labels`() {
        assertEquals("Verify your Aadhaar", profileCompletenessMissingItemLabel("aadhaar_verification"))
        assertEquals("Add and verify your PAN", profileCompletenessMissingItemLabel("pan_verified"))
        assertEquals("Complete police verification", profileCompletenessMissingItemLabel("police_verification"))
        assertEquals("Add at least one specialization", profileCompletenessMissingItemLabel("specializations"))
        assertEquals("Upload at least one certificate", profileCompletenessMissingItemLabel("certificates"))
        assertEquals("Add a profile photo", profileCompletenessMissingItemLabel("profile_photo"))
        assertEquals("Set your service location", profileCompletenessMissingItemLabel("location"))
        assertEquals("Set your minimum payout floor", profileCompletenessMissingItemLabel("profitability_floor"))
        assertEquals("Add your GSTIN", profileCompletenessMissingItemLabel("gstin"))
        assertEquals("Complete at least 6 jobs", profileCompletenessMissingItemLabel("needs_6_completed_jobs"))
    }

    @Test fun `unrecognised code falls back to a humanised raw string, not a crash`() {
        assertEquals("Some future code", profileCompletenessMissingItemLabel("some_future_code"))
    }
}
