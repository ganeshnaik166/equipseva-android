package com.equipseva.app.features.repair

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class RepairJobsFeedSubtitleTest {

    @Test fun `null radius reads N open all radii`() {
        assertEquals(
            "5 open · all radii",
            repairJobsFeedSubtitle(5, null),
        )
    }

    @Test fun `non-null radius reads N open within Nkm`() {
        assertEquals(
            "5 open within 25 km",
            repairJobsFeedSubtitle(5, 25),
        )
    }

    @Test fun `all radii phrasing preserved (not all areas)`() {
        // Pin "all radii" — mirrors the radius-chip vocabulary on
        // the same screen. A refactor to "all areas" / "everywhere"
        // would create vocab mismatch within the single surface.
        val out = repairJobsFeedSubtitle(1, null)
        assertTrue(out.contains("all radii"))
        assertEquals(false, out.contains("all areas"))
    }

    @Test fun `radius branch keeps km suffix with space`() {
        val out = repairJobsFeedSubtitle(1, 50)
        assertTrue(out.endsWith("50 km"))
    }

    @Test fun `0 count interpolates verbatim (defensive)`() {
        // Caller gates upstream, but pin total shape.
        assertEquals(
            "0 open · all radii",
            repairJobsFeedSubtitle(0, null),
        )
    }

    @Test fun `middle dot in null-radius branch is U+00B7`() {
        val out = repairJobsFeedSubtitle(1, null)
        assertTrue(out.contains(" · "))
    }

    @Test fun `large radius interpolates verbatim`() {
        assertEquals(
            "5 open within 100 km",
            repairJobsFeedSubtitle(5, 100),
        )
    }
}
