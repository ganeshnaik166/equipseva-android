package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the four pure derivations on the founder engineer-zones screen:
 *  - `founderZonesSummary` — header "X zones · Y engineers".
 *  - `founderPinnedZones` — filters rows missing lat/lng so the map
 *    doesn't pin at (0,0).
 *  - `founderZoneMarkerSnippet` — singular/plural ("1 verified engineer"
 *    vs "3 verified engineers").
 *  - `founderAvgPinLabel` — row-level coordinate caption.
 */
class FounderEngineerMapLogicTest {

    private fun zone(
        district: String,
        count: Int = 0,
        lat: Double? = null,
        lng: Double? = null,
    ) = FounderRepository.EngineerZoneRow(
        district = district,
        engineerCount = count,
        sampleLat = lat,
        sampleLng = lng,
    )

    @Test fun `summary sums engineerCount across rows`() {
        val rows = listOf(
            zone("Hyderabad", count = 18),
            zone("Nalgonda", count = 12),
            zone("Khammam", count = 3),
        )
        assertEquals("3 zones · 33 verified engineers", founderZonesSummary(rows))
    }

    @Test fun `summary on empty list shows 0 zones and 0 engineers`() {
        // The empty-list path is the visible state when the RPC hasn't
        // populated yet — never crash on a sumOf over an empty list.
        assertEquals("0 zones · 0 verified engineers", founderZonesSummary(emptyList()))
    }

    @Test fun `pinned drops rows missing either lat or lng`() {
        val good = zone("Hyderabad", count = 5, lat = 17.385, lng = 78.486)
        val noLat = zone("Nalgonda", count = 12, lat = null, lng = 79.26)
        val noLng = zone("Suryapet", count = 9, lat = 17.14, lng = null)
        val noBoth = zone("Warangal", count = 5, lat = null, lng = null)

        val pinned = founderPinnedZones(listOf(good, noLat, noLng, noBoth))

        assertEquals(1, pinned.size)
        assertEquals("Hyderabad", pinned[0].first.district)
        assertEquals(17.385, pinned[0].second, 0.0001)
        assertEquals(78.486, pinned[0].third, 0.0001)
    }

    @Test fun `pinned preserves the original order`() {
        // Founder taps a marker; we look up the row by district. If we
        // shuffle the list we'd render the wrong "selected" highlight.
        val a = zone("A", count = 1, lat = 1.0, lng = 1.0)
        val b = zone("B", count = 1, lat = 2.0, lng = 2.0)
        val c = zone("C", count = 1, lat = 3.0, lng = 3.0)

        val pinned = founderPinnedZones(listOf(a, b, c))

        assertEquals(listOf("A", "B", "C"), pinned.map { it.first.district })
    }

    @Test fun `pinned on an empty list is empty`() {
        assertTrue(founderPinnedZones(emptyList()).isEmpty())
    }

    @Test fun `marker snippet singular for exactly one engineer`() {
        // Singular form is the only branch that matters for grammar
        // pickiness; everything else (0, 2, 100) is plural.
        assertEquals("1 verified engineer", founderZoneMarkerSnippet(1))
    }

    @Test fun `marker snippet plural for zero and many engineers`() {
        // Zero is plural in English — "0 engineers".
        assertEquals("0 verified engineers", founderZoneMarkerSnippet(0))
        assertEquals("2 verified engineers", founderZoneMarkerSnippet(2))
        assertEquals("18 verified engineers", founderZoneMarkerSnippet(18))
    }

    @Test fun `avg pin label rounds to four decimals on both coords`() {
        // The map view stays low-zoom so 4-decimal precision is enough
        // to disambiguate cities without leaking the engineer's exact
        // dropped pin.
        assertEquals("Avg pin: 17.3850, 78.4867", founderAvgPinLabel(17.385, 78.4867))
    }

    @Test fun `avg pin label collapses to placeholder when either coord is null`() {
        // Half-pinned rows say "No coordinates pinned" so the founder
        // sees the gap instead of "0.0000, 78.4867".
        assertEquals("No coordinates pinned", founderAvgPinLabel(null, 78.4867))
        assertEquals("No coordinates pinned", founderAvgPinLabel(17.385, null))
        assertEquals("No coordinates pinned", founderAvgPinLabel(null, null))
    }
}
