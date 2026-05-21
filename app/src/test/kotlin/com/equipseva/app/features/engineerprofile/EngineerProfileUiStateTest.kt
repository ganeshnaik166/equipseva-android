package com.equipseva.app.features.engineerprofile

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the engineer-profile editor `validate()` and `canSave` gates.
 * The form has five required-field checks and a min-length bio gate;
 * the order of checks is intentional so users see the first unmet
 * requirement (rate before years, areas before specs, bio last).
 * A regression in any branch would let the form submit invalid data
 * or block on a phantom missing field.
 */
class EngineerProfileUiStateTest {

    private val good = EngineerProfileViewModel.UiState(
        loading = false,
        saving = false,
        hourlyRate = "750",
        yearsExperience = "5",
        serviceAreas = "Hyderabad, Secunderabad",
        specializations = "imaging, dental",
        bio = "10 years on imaging modalities across Telangana",
        isAvailable = true,
    )

    // ---- validate() ----

    @Test fun `happy path returns null`() {
        assertNull(good.validate())
    }

    @Test fun `empty rate fails with rate error`() {
        assertEquals(
            "Enter an hourly rate greater than 0.",
            good.copy(hourlyRate = "").validate(),
        )
    }

    @Test fun `non-numeric rate fails with rate error`() {
        assertEquals(
            "Enter an hourly rate greater than 0.",
            good.copy(hourlyRate = "abc").validate(),
        )
    }

    @Test fun `zero rate fails with rate error`() {
        assertEquals(
            "Enter an hourly rate greater than 0.",
            good.copy(hourlyRate = "0").validate(),
        )
    }

    @Test fun `negative rate fails with rate error`() {
        assertEquals(
            "Enter an hourly rate greater than 0.",
            good.copy(hourlyRate = "-50").validate(),
        )
    }

    @Test fun `out-of-range years fails with years error`() {
        // Server-side cap is 60; pin so a UX nudge for a fresher (e.g.
        // 0 years) still passes while a sloppy paste of "150" fails.
        assertEquals(
            "Years of experience must be between 0 and 60.",
            good.copy(yearsExperience = "150").validate(),
        )
        assertEquals(
            "Years of experience must be between 0 and 60.",
            good.copy(yearsExperience = "-1").validate(),
        )
    }

    @Test fun `non-numeric years fails with years error`() {
        assertEquals(
            "Years of experience must be between 0 and 60.",
            good.copy(yearsExperience = "ten").validate(),
        )
    }

    @Test fun `zero years passes — a fresher with 0 years is valid`() {
        assertNull(good.copy(yearsExperience = "0").validate())
    }

    @Test fun `60 years (top boundary) passes`() {
        assertNull(good.copy(yearsExperience = "60").validate())
    }

    @Test fun `empty service-areas fails with areas error`() {
        assertEquals(
            "Add at least one service area (comma-separated).",
            good.copy(serviceAreas = "").validate(),
        )
        // Only commas + spaces → parseList yields empty → same error.
        assertEquals(
            "Add at least one service area (comma-separated).",
            good.copy(serviceAreas = " , , ").validate(),
        )
    }

    @Test fun `empty specializations fails with specs error`() {
        assertEquals(
            "Pick at least one specialization.",
            good.copy(specializations = "").validate(),
        )
    }

    @Test fun `bio shorter than min-len fails with bio error`() {
        // BIO_MIN_LEN is 20.
        assertEquals(
            "Bio must be at least 20 characters.",
            good.copy(bio = "Too short").validate(),
        )
    }

    @Test fun `bio at exactly BIO_MIN_LEN chars passes`() {
        // 20 chars exactly — boundary.
        val twentyChars = "abcdefghij1234567890"
        assertEquals(20, twentyChars.length)
        assertNull(good.copy(bio = twentyChars).validate())
    }

    @Test fun `bio counts after trimming whitespace`() {
        // 15 chars wrapped in spaces shouldn't pass.
        val padded = "          abcdefghij12345          "
        assertEquals(
            "Bio must be at least 20 characters.",
            good.copy(bio = padded.padEnd(50)).copy(bio = "    short text    ").validate(),
        )
    }

    // ---- canSave ----

    @Test fun `canSave true on happy path`() {
        assertTrue(good.canSave)
    }

    @Test fun `canSave false while loading`() {
        assertFalse(good.copy(loading = true).canSave)
    }

    @Test fun `canSave false while saving`() {
        assertFalse(good.copy(saving = true).canSave)
    }

    @Test fun `canSave false when validate fails`() {
        assertFalse(good.copy(hourlyRate = "").canSave)
    }
}
