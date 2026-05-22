package com.equipseva.app.core.data.engineers

import org.junit.Test

/**
 * Pins the WGS84 lat/lng guard on engineer base-location updates.
 * The on-device picker filters to valid coords, but this is the last
 * line in front of the network — a non-UI caller (script, outbox
 * payload, future RPC) must not be able to write -91 / +200 / NaN.
 *
 * Inclusive bounds: lat in [-90, +90], lng in [-180, +180].
 */
class ValidateWgs84Test {

    @Test fun `valid coords pass`() {
        validateWgs84(12.97, 77.59)  // Bengaluru
        validateWgs84(0.0, 0.0)
        validateWgs84(-90.0, -180.0)  // boundary
        validateWgs84(90.0, 180.0)    // boundary
    }

    @Test(expected = IllegalArgumentException::class)
    fun `latitude below -90 throws`() {
        validateWgs84(-90.001, 0.0)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `latitude above +90 throws`() {
        validateWgs84(90.001, 0.0)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `longitude below -180 throws`() {
        validateWgs84(0.0, -180.001)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `longitude above +180 throws`() {
        validateWgs84(0.0, 180.001)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `NaN latitude throws`() {
        validateWgs84(Double.NaN, 0.0)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `NaN longitude throws`() {
        validateWgs84(0.0, Double.NaN)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `positive infinity latitude throws (out of range)`() {
        validateWgs84(Double.POSITIVE_INFINITY, 0.0)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `negative infinity longitude throws (out of range)`() {
        validateWgs84(0.0, Double.NEGATIVE_INFINITY)
    }

    @Test fun `error message includes the offending coordinate`() {
        try {
            validateWgs84(95.0, 0.0)
        } catch (e: IllegalArgumentException) {
            // The exception message must include the offending value
            // so a future log capture can triage which call site sent
            // the bad coord.
            assert(e.message?.contains("95") == true) { "expected '95' in: ${e.message}" }
            return
        }
        error("expected IllegalArgumentException")
    }
}
