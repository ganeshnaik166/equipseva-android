package com.equipseva.app.features.engineerprofile

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The engineer self-profile editor (entered from the Jobs hub) writes
 * hourly_rate, years_experience, service_areas, specializations, bio,
 * is_available straight into engineers.*. The validate() function is
 * the single point of truth for what blocks save; canSave wraps it
 * plus the in-flight guard. Pin every branch + the parseList /
 * formatRate helpers.
 */
class EngineerProfileUiStateTest {

    private fun good() = EngineerProfileViewModel.UiState(
        loading = false,
        hourlyRate = "1500",
        yearsExperience = "5",
        serviceAreas = "Bangalore, Mysuru",
        specializations = "Imaging, Patient monitoring",
        bio = "Twelve years on imaging equipment across Karnataka and Tamil Nadu.",
    )

    @Test fun `happy path is saveable`() {
        val state = good()
        assertNull(state.validate())
        assertTrue(state.canSave)
    }

    @Test fun `loading or saving blocks canSave even when validate is null`() {
        val state = good()
        assertFalse(state.copy(loading = true).canSave)
        assertFalse(state.copy(saving = true).canSave)
    }

    @Test fun `non-positive hourly rate fails validation`() {
        assertEquals(
            "Enter an hourly rate greater than 0.",
            good().copy(hourlyRate = "0").validate(),
        )
        assertEquals(
            "Enter an hourly rate greater than 0.",
            good().copy(hourlyRate = "-50").validate(),
        )
        assertEquals(
            "Enter an hourly rate greater than 0.",
            good().copy(hourlyRate = "").validate(),
        )
        assertEquals(
            "Enter an hourly rate greater than 0.",
            good().copy(hourlyRate = "abc").validate(),
        )
    }

    @Test fun `years experience must be in 0 to 60`() {
        val expected = "Years of experience must be between 0 and 60."
        assertEquals(expected, good().copy(yearsExperience = "-1").validate())
        assertEquals(expected, good().copy(yearsExperience = "61").validate())
        assertEquals(expected, good().copy(yearsExperience = "x").validate())
        // Boundary values pass.
        assertNull(good().copy(yearsExperience = "0").validate())
        assertNull(good().copy(yearsExperience = "60").validate())
    }

    @Test fun `service areas requires at least one comma-separated entry`() {
        assertEquals(
            "Add at least one service area (comma-separated).",
            good().copy(serviceAreas = "").validate(),
        )
        // Blank-and-comma-only inputs fall to the same error — parseList
        // collapses them.
        assertEquals(
            "Add at least one service area (comma-separated).",
            good().copy(serviceAreas = "  ,  ,  ").validate(),
        )
    }

    @Test fun `specializations requires at least one comma-separated entry`() {
        assertEquals(
            "Add at least one specialization (comma-separated).",
            good().copy(specializations = "   ").validate(),
        )
    }

    @Test fun `bio under the minimum length fails`() {
        val short = "Too short"
        val result = good().copy(bio = short).validate()
        assertTrue("expected length message, got $result", result?.startsWith("Bio must be at least") == true)
        // Ensure the const is referenced in the message so renaming it
        // doesn't silently desynchronize.
        assertTrue(result!!.contains("$BIO_MIN_LEN"))
    }

    @Test fun `parseList splits comma-separated input and drops blanks`() {
        assertEquals(
            listOf("Bangalore", "Mysuru"),
            parseList("Bangalore, Mysuru"),
        )
        assertEquals(
            listOf("Bangalore", "Mysuru"),
            parseList("  Bangalore  ,  Mysuru  "),
        )
        assertEquals(
            listOf("Bangalore"),
            parseList(",,Bangalore,,"),
        )
        assertTrue(parseList("   ,   ").isEmpty())
        assertTrue(parseList("").isEmpty())
    }

    @Test fun `formatRate strips trailing zero noise but keeps the fractional part`() {
        assertEquals("75", formatRate(75.0))
        assertEquals("0", formatRate(0.0))
        assertEquals("75.5", formatRate(75.5))
        assertEquals("1500", formatRate(1500.0))
    }
}
