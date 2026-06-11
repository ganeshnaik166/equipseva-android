package com.equipseva.app.features.repair.directory

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins the directory-row "city · distance · typical-bid" line composer.
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
 *   * Round 471 swap: hourlyRate → typicalBidMin/typicalBidMax. The
 *     "Hourly ₹1,800" copy misled hospitals into thinking jobs were
 *     billed per-hour; bids on EquipSeva are per-job.
 */
class FormatDirectoryRowLocationLineTest {

    @Test fun `all three parts join with middle-dot separator`() {
        assertEquals(
            "Bengaluru · 3.2 km · Typical bid: ₹4,000–₹10,000",
            formatDirectoryRowLocationLine(
                city = "Bengaluru",
                distanceKm = 3.2,
                typicalBidMin = 4000.0,
                typicalBidMax = 10000.0,
            ),
        )
    }

    @Test fun `only city renders city alone`() {
        assertEquals(
            "Bengaluru",
            formatDirectoryRowLocationLine(
                city = "Bengaluru",
                distanceKm = null,
                typicalBidMin = null,
                typicalBidMax = null,
            ),
        )
    }

    @Test fun `only distance renders distance alone`() {
        assertEquals(
            "5.4 km",
            formatDirectoryRowLocationLine(
                city = null,
                distanceKm = 5.4,
                typicalBidMin = null,
                typicalBidMax = null,
            ),
        )
    }

    @Test fun `only bid range renders bid alone with Typical bid prefix`() {
        assertEquals(
            "Typical bid: ₹4,000–₹10,000",
            formatDirectoryRowLocationLine(
                city = null,
                distanceKm = null,
                typicalBidMin = 4000.0,
                typicalBidMax = 10000.0,
            ),
        )
    }

    @Test fun `city plus bid (no distance) joins with one separator`() {
        assertEquals(
            "Bengaluru · Typical bid: ₹4,000–₹10,000",
            formatDirectoryRowLocationLine(
                city = "Bengaluru",
                distanceKm = null,
                typicalBidMin = 4000.0,
                typicalBidMax = 10000.0,
            ),
        )
    }

    @Test fun `all null returns null (caller hides the line)`() {
        assertNull(formatDirectoryRowLocationLine(null, null, null, null))
    }

    @Test fun `blank city omitted just like null`() {
        // Pin so an empty city doesn't leak as a leading " · ".
        assertEquals(
            "3.2 km · Typical bid: ₹4,000–₹10,000",
            formatDirectoryRowLocationLine(
                city = "  ",
                distanceKm = 3.2,
                typicalBidMin = 4000.0,
                typicalBidMax = 10000.0,
            ),
        )
    }

    @Test fun `distance formatted under Locale-US (dot decimal)`() {
        val out = formatDirectoryRowLocationLine(
            city = null,
            distanceKm = 3.2,
            typicalBidMin = null,
            typicalBidMax = null,
        )
        assertEquals("3.2 km", out)
        assertEquals(false, out!!.contains("3,2"))
    }

    @Test fun `distance has space between number and km (directory variant)`() {
        // Pin so a refactor that consolidated with engineerCardLocationLine
        // (no-space variant for tight home-card carousel) doesn't drift.
        val out = formatDirectoryRowLocationLine(null, 3.2, null, null)
        assertEquals(true, out!!.contains("3.2 km"))
        assertEquals(false, out.contains("3.2km"))
    }

    @Test fun `bid range uses formatRupees for Indian lakh grouping`() {
        // 100000 → "₹1,00,000" (lakh grouping)
        val out = formatDirectoryRowLocationLine(null, null, 100000.0, 250000.0)
        assertEquals("Typical bid: ₹1,00,000–₹2,50,000", out)
    }

    @Test fun `middle-dot separator is U+00B7 (not ASCII)`() {
        val out = formatDirectoryRowLocationLine("Bengaluru", 3.2, 4000.0, 10000.0)!!
        assertEquals(2, out.count { it == '·' })
    }

    // ---- formatBidRange ----

    @Test fun `formatBidRange both bounds yields Typical bid prefix and en-dash range`() {
        assertEquals(
            "Typical bid: ₹4,000–₹10,000",
            formatBidRange(4000.0, 10000.0),
        )
    }

    @Test fun `formatBidRange null min returns null (incomplete band)`() {
        assertNull(formatBidRange(null, 10000.0))
    }

    @Test fun `formatBidRange null max returns null (incomplete band)`() {
        assertNull(formatBidRange(4000.0, null))
    }

    @Test fun `formatBidRange both null returns null (no data)`() {
        assertNull(formatBidRange(null, null))
    }

    @Test fun `formatBidRange both zero returns null (no real data)`() {
        assertNull(formatBidRange(0.0, 0.0))
    }

    @Test fun `formatBidRange equal bounds collapses to single price`() {
        // Pin so a "₹5,000–₹5,000" duplicate doesn't surface when an
        // engineer has done 5 identical jobs.
        assertEquals("Typical bid: ₹5,000", formatBidRange(5000.0, 5000.0))
    }

    @Test fun `formatBidRange separator is en-dash U+2013 not hyphen`() {
        // Pin so a refactor doesn't surface "₹4,000-₹10,000" (ASCII
        // hyphen) — typographically the wrong glyph for a numeric range.
        val out = formatBidRange(4000.0, 10000.0)!!
        assertEquals(true, out.contains('–'))
        // Make sure the only non-numeric joiner is the en-dash, not
        // an ASCII hyphen.
        assertEquals(false, out.contains('-'))
    }
}
