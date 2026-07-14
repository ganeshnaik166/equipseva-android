package com.equipseva.app.features.engineerprofile

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins for the r1395 profile-completeness helpers. */
class ProfileCompletenessHelpersTest {

    @Test fun `band pill maps each server band`() {
        assertEquals("Complete" to PillKind.Success, completenessBandTextAndKind("complete"))
        assertEquals("Almost there" to PillKind.Warn, completenessBandTextAndKind("partial"))
        assertEquals("Incomplete" to PillKind.Danger, completenessBandTextAndKind("incomplete"))
    }

    @Test fun `unknown band defaults to incomplete-danger`() {
        assertEquals("Incomplete" to PillKind.Danger, completenessBandTextAndKind("something_new"))
    }

    @Test fun `known missing-item keys get human labels`() {
        assertEquals("Verify your Aadhaar", missingItemLabel("aadhaar_verification"))
        assertEquals("Set your net-pay floor", missingItemLabel("profitability_floor"))
        assertEquals("Complete 6 repair jobs", missingItemLabel("needs_6_completed_jobs"))
        assertEquals("Add your GSTIN", missingItemLabel("gstin"))
    }

    @Test fun `unknown key degrades to de-snaked title case`() {
        assertEquals("Some new thing", missingItemLabel("some_new_thing"))
    }
}
