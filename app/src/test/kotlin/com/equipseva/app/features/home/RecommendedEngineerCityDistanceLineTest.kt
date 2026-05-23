package com.equipseva.app.features.home

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Locale

class RecommendedEngineerCityDistanceLineTest {

    @Test fun `both city and distance present join with middle dot`() {
        assertEquals(
            "Hyderabad · 3.2 km",
            recommendedEngineerCityDistanceLine("Hyderabad", 3.2),
        )
    }

    @Test fun `city alone passes through`() {
        assertEquals(
            "Hyderabad",
            recommendedEngineerCityDistanceLine("Hyderabad", null),
        )
    }

    @Test fun `distance alone shows formatted km without city`() {
        assertEquals(
            "3.2 km",
            recommendedEngineerCityDistanceLine(null, 3.2),
        )
    }

    @Test fun `both null returns null (caller hides row)`() {
        // Critical pin — collapses to null, not empty string.
        assertNull(recommendedEngineerCityDistanceLine(null, null))
    }

    @Test fun `distance formatter is Locale-ENGLISH stable not device-locale`() {
        // Hindi-locale would render "3,2 km" if Locale.ENGLISH were
        // dropped. Pin by saving + restoring the default locale.
        val saved = Locale.getDefault()
        try {
            Locale.setDefault(Locale.forLanguageTag("hi-IN"))
            assertEquals(
                "Hyderabad · 5.7 km",
                recommendedEngineerCityDistanceLine("Hyderabad", 5.7),
            )
            Locale.setDefault(Locale.GERMANY)
            assertEquals(
                "Hyderabad · 5.7 km",
                recommendedEngineerCityDistanceLine("Hyderabad", 5.7),
            )
            Locale.setDefault(Locale.forLanguageTag("fr-FR"))
            assertEquals(
                "Hyderabad · 5.7 km",
                recommendedEngineerCityDistanceLine("Hyderabad", 5.7),
            )
        } finally {
            Locale.setDefault(saved)
        }
    }

    @Test fun `whole-km distance still shows one decimal`() {
        // Pin %.1f over %.0f — sub-km precision is load-bearing for
        // engineers within a few km of the hospital.
        assertEquals(
            "Hyderabad · 5.0 km",
            recommendedEngineerCityDistanceLine("Hyderabad", 5.0),
        )
    }

    @Test fun `sub-km distance shows decimal not folded to 0`() {
        // Critical pin — an engineer 0.4km away should NOT read
        // "0 km" (which feels broken).
        assertEquals(
            "Hyderabad · 0.4 km",
            recommendedEngineerCityDistanceLine("Hyderabad", 0.4),
        )
    }

    @Test fun `middle dot is U+00B7 not bullet`() {
        val out = recommendedEngineerCityDistanceLine("X", 1.0)
        assertTrue(out!!.contains('·'))
        assertEquals(false, out.contains('•'))
    }

    @Test fun `distance rounds to one decimal half-up`() {
        assertEquals(
            "X · 3.3 km",
            recommendedEngineerCityDistanceLine("X", 3.25),
        )
    }
}
