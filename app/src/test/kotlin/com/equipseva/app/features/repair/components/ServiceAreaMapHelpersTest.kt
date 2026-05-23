package com.equipseva.app.features.repair.components

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the radius → map-zoom mapping. A 50 km service radius needs a
 * far-out zoom to keep the whole circle visible on a phone screen;
 * 10 km can comfortably go tighter. Caught here so a tuning pass
 * doesn't accidentally invert the relationship and crop the radius
 * circle off-screen on the engineer profile preview.
 */
class ServiceAreaMapHelpersTest {

    @Test fun `null radius defaults to city-level zoom`() {
        assertEquals(10f, zoomFor(null), 0.0f)
    }

    @Test fun `radius of 10 or less zooms tightest`() {
        assertEquals(12f, zoomFor(1), 0.0f)
        assertEquals(12f, zoomFor(10), 0.0f)
    }

    @Test fun `radius 11 to 25 zooms one step out`() {
        assertEquals(11f, zoomFor(11), 0.0f)
        assertEquals(11f, zoomFor(25), 0.0f)
    }

    @Test fun `radius 26 to 50 zooms to city level`() {
        assertEquals(10f, zoomFor(26), 0.0f)
        assertEquals(10f, zoomFor(50), 0.0f)
    }

    @Test fun `radius over 50 zooms regional`() {
        assertEquals(9f, zoomFor(51), 0.0f)
        assertEquals(9f, zoomFor(500), 0.0f)
    }

    @Test fun `radius zero or negative still produces a sensible zoom`() {
        // The picker form can't currently emit zero, but pin the
        // behaviour so an edge-input doesn't crash + show a black map.
        assertEquals(12f, zoomFor(0), 0.0f)
        assertEquals(12f, zoomFor(-5), 0.0f)
    }
}
