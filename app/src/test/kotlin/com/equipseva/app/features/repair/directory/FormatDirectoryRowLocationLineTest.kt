package com.equipseva.app.features.repair.directory

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins the directory-row "city · distance · rate" line composer.
 *
 * Critical regions:
 *   * Returns null on all-empty so the caller doesn't render an
 *     empty Text() / extra Spacer.
 *   * Distance uses Locale.US so a Hindi-locale device doesn't
 *     surface "3,2 km" instead of "3.2 km".
 *   * Spaced "km" suffix — sibling helper engineerCardLocationLine
 *     uses no-space "km" (different space budget on home carousel
 *     card vs directory row). Pin both so a future "consolidate
 *     across surfaces" change is reviewed.
 *   * Middle-dot separator (U+00B7) — pin matches sibling helpers.
 */
class FormatDirectoryRowLocationLineTest {

    @Test fun `all three parts join with middle-dot separator`() {
        assertEquals(
            "Bengaluru · 3.2 km · ₹750/hr",
            formatDirectoryRowLocationLine(
                city = "Bengaluru",
                distanceKm = 3.2,
                hourlyRate = 750.0,
            ),
        )
    }

    @Test fun `only city renders city alone`() {
        assertEquals(
            "Bengaluru",
            formatDirectoryRowLocationLine(city = "Bengaluru", distanceKm = null, hourlyRate = null),
        )
    }

    @Test fun `only distance renders distance alone`() {
        assertEquals(
            "5.4 km",
            formatDirectoryRowLocationLine(city = null, distanceKm = 5.4, hourlyRate = null),
        )
    }

    @Test fun `only rate renders rate alone with per-hour suffix`() {
        assertEquals(
            "₹750/hr",
            formatDirectoryRowLocationLine(city = null, distanceKm = null, hourlyRate = 750.0),
        )
    }

    @Test fun `city plus rate (no distance) joins with one separator`() {
        assertEquals(
            "Bengaluru · ₹500/hr",
            formatDirectoryRowLocationLine(
                city = "Bengaluru",
                distanceKm = null,
                hourlyRate = 500.0,
            ),
        )
    }

    @Test fun `all null returns null (caller hides the line)`() {
        assertNull(formatDirectoryRowLocationLine(null, null, null))
    }

    @Test fun `blank city omitted just like null`() {
        // Pin so an empty city doesn't leak as a leading " · ".
        assertEquals(
            "3.2 km · ₹750/hr",
            formatDirectoryRowLocationLine(
                city = "  ",
                distanceKm = 3.2,
                hourlyRate = 750.0,
            ),
        )
    }

    @Test fun `distance formatted under Locale-US (dot decimal)`() {
        val out = formatDirectoryRowLocationLine(
            city = null,
            distanceKm = 3.2,
            hourlyRate = null,
        )
        assertEquals("3.2 km", out)
        assertEquals(false, out!!.contains("3,2"))
    }

    @Test fun `distance has space between number and km (directory variant)`() {
        // Pin so a refactor that consolidated with engineerCardLocationLine
        // (no-space variant for tight home-card carousel) doesn't drift.
        val out = formatDirectoryRowLocationLine(null, 3.2, null)
        assertEquals(true, out!!.contains("3.2 km"))
        assertEquals(false, out.contains("3.2km"))
    }

    @Test fun `rate uses formatRupees for Indian lakh grouping`() {
        // 100000 → "₹1,00,000/hr" (lakh grouping)
        val out = formatDirectoryRowLocationLine(null, null, 100000.0)
        assertEquals("₹1,00,000/hr", out)
    }

    @Test fun `middle-dot separator is U+00B7 (not ASCII)`() {
        val out = formatDirectoryRowLocationLine("Bengaluru", 3.2, 750.0)!!
        assertEquals(2, out.count { it == '·' })
    }
}
