package com.equipseva.app.features.amc

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the AMC visit-frequency → visits-per-year mapping. The wizard
 * pre-fills the visits-per-year field as soon as a frequency option is
 * picked; a regression here would either zero-out the field (unknown
 * fallback) or compute the wrong annual visit count which propagates
 * into the SLA + monthly fee calculation downstream.
 *
 * Pinned values mirror the server-side `amc_contracts.visit_frequency`
 * enum convention.
 */
class VisitsPerYearForFrequencyTest {

    @Test fun `weekly is 52 visits per year`() {
        assertEquals(52, visitsPerYearForFrequency("weekly"))
    }

    @Test fun `biweekly is 26 visits per year (every two weeks)`() {
        assertEquals(26, visitsPerYearForFrequency("biweekly"))
    }

    @Test fun `monthly is 12 visits per year`() {
        assertEquals(12, visitsPerYearForFrequency("monthly"))
    }

    @Test fun `quarterly is 4 visits per year (one per quarter)`() {
        assertEquals(4, visitsPerYearForFrequency("quarterly"))
    }

    @Test fun `unknown frequency falls back to monthly (12)`() {
        // Forward-compat: a server-side new frequency option must NOT
        // zero-out the field — the safest fallback is monthly so the
        // SLA / fee math downstream produces a non-degenerate number.
        assertEquals(12, visitsPerYearForFrequency("annually"))
        assertEquals(12, visitsPerYearForFrequency("future_cadence"))
    }

    @Test fun `empty string falls back to monthly (defensive)`() {
        assertEquals(12, visitsPerYearForFrequency(""))
    }

    @Test fun `case-sensitive matching`() {
        // The DB enum is lowercase. Pin so a tolerant lowercase()
        // refactor doesn't silently get added.
        assertEquals(12, visitsPerYearForFrequency("WEEKLY"))
        assertEquals(12, visitsPerYearForFrequency("Monthly"))
    }

    @Test fun `weekly count divides evenly into a 52-week year`() {
        // Defensive: 52 / 52 = 1 visit per week; the SLA cadence
        // helper downstream depends on this. Pin the literal so a
        // typo (51) doesn't slip past.
        assertEquals(52, visitsPerYearForFrequency("weekly"))
    }
}
