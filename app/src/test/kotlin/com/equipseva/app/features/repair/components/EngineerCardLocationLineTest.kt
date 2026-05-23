package com.equipseva.app.features.repair.components

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins the engineer-card "city · distance" line composer.
 *
 * Critical regions:
 *   * null return on both-empty so the caller doesn't render an
 *     empty Text() / extra Spacer (drop the row entirely).
 *   * Locale-US distance format ("3.2km" not "3,2km") on Hindi-
 *     locale devices.
 *   * Middle-dot separator (U+00B7) — sibling to formatReviewWhenAndCity.
 */
class EngineerCardLocationLineTest {

    @Test fun `city + distance joins with middle-dot separator`() {
        assertEquals(
            "Bengaluru · 3.2km",
            engineerCardLocationLine(city = "Bengaluru", distanceKm = 3.2),
        )
    }

    @Test fun `only city renders city without separator or distance`() {
        assertEquals(
            "Bengaluru",
            engineerCardLocationLine(city = "Bengaluru", distanceKm = null),
        )
    }

    @Test fun `only distance renders distance without separator or city`() {
        assertEquals(
            "5.4km",
            engineerCardLocationLine(city = null, distanceKm = 5.4),
        )
    }

    @Test fun `both null returns null (caller hides the row)`() {
        assertNull(engineerCardLocationLine(city = null, distanceKm = null))
    }

    @Test fun `blank city falls back to distance-only`() {
        // Pin so an empty / whitespace-only city doesn't surface
        // as " · 3.2km" trailing-leading-separator garbage.
        assertEquals("3.2km", engineerCardLocationLine(city = "  ", distanceKm = 3.2))
        assertEquals("3.2km", engineerCardLocationLine(city = "", distanceKm = 3.2))
    }

    @Test fun `blank city and null distance returns null`() {
        assertNull(engineerCardLocationLine(city = "   ", distanceKm = null))
    }

    @Test fun `distance formatted to 1 decimal place`() {
        assertEquals(
            "Bengaluru · 0.5km",
            engineerCardLocationLine(city = "Bengaluru", distanceKm = 0.5),
        )
        assertEquals(
            "Bengaluru · 12.0km",
            engineerCardLocationLine(city = "Bengaluru", distanceKm = 12.0),
        )
    }

    @Test fun `distance uses Locale-US dot decimal (not comma)`() {
        // Critical — pin so a refactor that dropped Locale.US doesn't
        // surface "3,2km" on Hindi-locale devices.
        val out = engineerCardLocationLine(city = null, distanceKm = 3.2)
        assertEquals("3.2km", out)
        assertEquals(false, out!!.contains("3,2"))
    }

    @Test fun `large distance values pass through`() {
        assertEquals(
            "Hyderabad · 120.5km",
            engineerCardLocationLine(city = "Hyderabad", distanceKm = 120.5),
        )
    }

    @Test fun `middle-dot separator pinned (U+00B7 not ASCII)`() {
        val out = engineerCardLocationLine(city = "Bengaluru", distanceKm = 3.2)!!
        assertEquals(true, out.contains('·'))
        assertEquals(false, out.contains('*'))
    }
}
