package com.equipseva.app.features.repair.directory

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs

/**
 * Pins the great-circle distance helper used by the
 * EngineerPublicProfile screen's "≥50 km away → show alternatives"
 * gate. The numeric correctness matters because the gate decides
 * whether the carousel shows alternative engineers — too-tight a
 * tolerance and a 51km gap reads as 49km (no carousel for a long-haul
 * hospital), too-loose and a 49km gap reads as 51km (carousel for a
 * neighbouring hospital).
 *
 * Reference values computed against an online haversine calculator
 * with Earth radius 6371 km, the same constant the impl uses.
 */
class HaversineKmTest {

    private fun assertNear(expected: Double, actual: Double, tolerance: Double) {
        assertTrue(
            "expected $expected ± $tolerance, got $actual (diff=${abs(actual - expected)})",
            abs(actual - expected) <= tolerance,
        )
    }

    @Test fun `distance from a point to itself is zero`() {
        assertEquals(0.0, haversineKm(12.97, 77.59, 12.97, 77.59), 1e-9)
    }

    @Test fun `Bengaluru to Chennai is approximately 290 km`() {
        // Bengaluru: 12.9716, 77.5946; Chennai: 13.0827, 80.2707.
        // Reference: ~290 km.
        val km = haversineKm(12.9716, 77.5946, 13.0827, 80.2707)
        assertNear(290.0, km, 1.5)
    }

    @Test fun `Mumbai to Pune is approximately 120 km`() {
        // Mumbai: 19.0760, 72.8777; Pune: 18.5204, 73.8567.
        val km = haversineKm(19.0760, 72.8777, 18.5204, 73.8567)
        assertNear(120.0, km, 1.5)
    }

    @Test fun `Delhi to Bengaluru is approximately 1740 km`() {
        // Delhi: 28.6139, 77.2090; Bengaluru: 12.9716, 77.5946.
        val km = haversineKm(28.6139, 77.2090, 12.9716, 77.5946)
        assertNear(1740.0, km, 5.0)
    }

    @Test fun `Order of args doesn't matter (commutative)`() {
        val a = haversineKm(12.97, 77.59, 13.08, 80.27)
        val b = haversineKm(13.08, 80.27, 12.97, 77.59)
        assertEquals(a, b, 1e-9)
    }

    @Test fun `Antipodal points yield approximately half the great circle`() {
        // Earth's circumference along a meridian ≈ 2 * pi * 6371 ≈ 40030 km.
        // Antipode → 20015 km. Pick two simple antipodes: (0, 0) and (0, 180).
        val km = haversineKm(0.0, 0.0, 0.0, 180.0)
        assertNear(20015.0, km, 5.0)
    }

    @Test fun `One degree of latitude is approximately 111 km`() {
        // Pin the per-degree constant; surfaces a regression in the
        // 6371 km radius constant.
        val km = haversineKm(12.0, 77.0, 13.0, 77.0)
        assertNear(111.2, km, 0.5)
    }
}
