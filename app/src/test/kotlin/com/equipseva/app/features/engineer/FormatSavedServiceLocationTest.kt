package com.equipseva.app.features.engineer

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Locale

/**
 * Pins the "Currently saved" caption on the engineer service-location
 * screen. Critical region: Locale.US stability + 5-decimal precision
 * (≈1.1m at the equator).
 */
class FormatSavedServiceLocationTest {

    @Test fun `renders 5-decimal precision with US locale`() {
        assertEquals(
            "Currently saved: 17.38505, 78.45670",
            formatSavedServiceLocation(17.38505, 78.4567),
        )
    }

    @Test fun `rounds to 5 decimals half-up`() {
        // %.5f does half-up rounding. Pin so a precision change
        // surfaces here.
        assertEquals(
            "Currently saved: 17.38506, 78.45678",
            formatSavedServiceLocation(17.385055, 78.4567849),
        )
    }

    @Test fun `formatter is Locale-US stable, not device-locale`() {
        // Critical regression target — Hindi/German locale would
        // render "17,38505" if Locale.US were dropped. Pin by
        // setting and restoring the default locale around the call.
        val saved = Locale.getDefault()
        try {
            Locale.setDefault(Locale.forLanguageTag("hi-IN"))
            assertEquals(
                "Currently saved: 12.97432, 77.59465",
                formatSavedServiceLocation(12.97432, 77.59465),
            )
            Locale.setDefault(Locale.GERMANY)
            assertEquals(
                "Currently saved: 12.97432, 77.59465",
                formatSavedServiceLocation(12.97432, 77.59465),
            )
            Locale.setDefault(Locale.forLanguageTag("fr-FR"))
            assertEquals(
                "Currently saved: 12.97432, 77.59465",
                formatSavedServiceLocation(12.97432, 77.59465),
            )
        } finally {
            Locale.setDefault(saved)
        }
    }

    @Test fun `Currently saved prefix is preserved verbatim`() {
        // Pin literal — a refactor to "Saved location:" or "Saved:"
        // would surface here.
        val out = formatSavedServiceLocation(0.0, 0.0)
        assertTrue(out.startsWith("Currently saved: "))
    }

    @Test fun `coordinates are comma-space separated, not slashed or middle-dotted`() {
        val out = formatSavedServiceLocation(1.0, 2.0)
        assertTrue(out.contains(", "))
        assertEquals(false, out.contains(" · "))
        assertEquals(false, out.contains(" / "))
    }

    @Test fun `negative coordinates render with leading minus and 5 decimals`() {
        // Pin so a refactor that absoluted the value before format
        // (lossy on southern/western hemispheres) surfaces.
        assertEquals(
            "Currently saved: -33.86880, -151.20930",
            formatSavedServiceLocation(-33.8688, -151.2093),
        )
    }

    @Test fun `whole-number coordinates still show 5 trailing zeros`() {
        // Pin so a refactor to %g (which strips trailing zeros)
        // surfaces.
        assertEquals(
            "Currently saved: 0.00000, 0.00000",
            formatSavedServiceLocation(0.0, 0.0),
        )
    }
}
