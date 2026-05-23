package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Locale

class ZoneRowSampleCoordinateLineTest {

    @Test fun `both coords present renders Avg pin with 4 decimals`() {
        assertEquals(
            "Avg pin: 17.3850, 78.4567",
            zoneRowSampleCoordinateLine(17.385, 78.4567),
        )
    }

    @Test fun `precision is 4 decimals (distinct from saved-location 5)`() {
        // Pin %.4f over %.5f — district-level averaged pin is
        // false-precision at 5 decimals.
        val out = zoneRowSampleCoordinateLine(17.123456789, 78.987654321)
        assertTrue(out.contains("17.1235"))  // half-up at 4 decimals
        assertTrue(out.contains("78.9877"))
        assertEquals(false, out.contains("17.12346"))  // would be 5dp
    }

    @Test fun `formatter is Locale-US stable, not device-locale`() {
        // Hindi/German locale would render "17,3850" if Locale.US
        // were dropped. Pin by setting and restoring the locale.
        val saved = Locale.getDefault()
        try {
            Locale.setDefault(Locale.forLanguageTag("hi-IN"))
            assertEquals(
                "Avg pin: 17.3850, 78.4567",
                zoneRowSampleCoordinateLine(17.385, 78.4567),
            )
            Locale.setDefault(Locale.GERMANY)
            assertEquals(
                "Avg pin: 17.3850, 78.4567",
                zoneRowSampleCoordinateLine(17.385, 78.4567),
            )
        } finally {
            Locale.setDefault(saved)
        }
    }

    @Test fun `null lat falls back to No coordinates pinned`() {
        assertEquals(
            "No coordinates pinned",
            zoneRowSampleCoordinateLine(null, 78.4567),
        )
    }

    @Test fun `null lng falls back to No coordinates pinned`() {
        assertEquals(
            "No coordinates pinned",
            zoneRowSampleCoordinateLine(17.385, null),
        )
    }

    @Test fun `both null falls back to No coordinates pinned`() {
        assertEquals(
            "No coordinates pinned",
            zoneRowSampleCoordinateLine(null, null),
        )
    }

    @Test fun `Avg pin prefix is preserved (not just Pin or Avg)`() {
        // Pin literal — "Pin:" would imply engineer's actual pin,
        // not the district average. "Avg" alone wouldn't anchor as
        // a coordinate.
        val out = zoneRowSampleCoordinateLine(0.0, 0.0)
        assertTrue(out.startsWith("Avg pin: "))
    }

    @Test fun `negative coords render with leading minus`() {
        assertEquals(
            "Avg pin: -33.8688, -151.2093",
            zoneRowSampleCoordinateLine(-33.8688, -151.2093),
        )
    }
}
