package com.equipseva.app.features.engineerprofile

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the two input sanitisers on the engineer-profile editor.
 *
 * Critical region (both): reject Devanagari / Arabic numerals. The
 * field shows "filled" via take(N) on the client but the server's
 * Double.toDoubleOrNull / Int.toIntOrNull can't parse non-ASCII
 * digits — save would fail as "amount required" without telling
 * the user that their unicode-digit-looking input is the problem.
 *
 * Rate-specific: keep first '.', strip subsequent dots (no "75.5.5"
 * shape).
 */
class SanitizeRateAndYearsTest {

    // ---- sanitizeHourlyRateInput ----

    @Test fun `clean integer input passes through`() {
        assertEquals("750", sanitizeHourlyRateInput("750"))
    }

    @Test fun `clean decimal input keeps the single dot`() {
        assertEquals("750.5", sanitizeHourlyRateInput("750.5"))
    }

    @Test fun `Devanagari digits rejected entirely`() {
        assertEquals("", sanitizeHourlyRateInput("७५०"))
    }

    @Test fun `Arabic-Indic digits rejected entirely`() {
        assertEquals("", sanitizeHourlyRateInput("٧٥٠"))
    }

    @Test fun `mixed ASCII and Devanagari keeps only ASCII digits`() {
        // "7५0" — the Devanagari "५" gets stripped, leaving the
        // ASCII "70" (NOT "75" — the Devanagari char was the middle
        // digit). Pin so the strip semantics stay strict.
        assertEquals("70", sanitizeHourlyRateInput("7५0"))
    }

    @Test fun `letters stripped but dot in Rs prefix surfaces as leading dot`() {
        // The dot in "Rs." passes the whitelist. Pin so a future
        // tightening (e.g. require digit before first dot) surfaces
        // in review — the current behavior keeps the dot at index 0.
        assertEquals(".750", sanitizeHourlyRateInput("Rs. 7Z50 INR"))
    }

    @Test fun `multiple dots collapse to first`() {
        // "75.5.5" → keep first dot, strip rest: "75.55"
        assertEquals("75.55", sanitizeHourlyRateInput("75.5.5"))
    }

    @Test fun `leading dot is preserved`() {
        // ".5" is valid decimal shape; pin so the helper doesn't
        // forcibly prepend "0".
        assertEquals(".5", sanitizeHourlyRateInput(".5"))
    }

    @Test fun `trailing dot is preserved (user mid-typing)`() {
        // "75." is a legitimate intermediate state — preserve so
        // typing doesn't fight back.
        assertEquals("75.", sanitizeHourlyRateInput("75."))
    }

    @Test fun `negative sign stripped (server-side cap on rate enforces positive)`() {
        // Minus sign isn't in the whitelist — pin so a paste of
        // "-100" sanitises to "100" rather than crashing or
        // accepting the negative.
        assertEquals("100", sanitizeHourlyRateInput("-100"))
    }

    @Test fun `blank input yields blank`() {
        assertEquals("", sanitizeHourlyRateInput(""))
        assertEquals("", sanitizeHourlyRateInput("   "))
    }

    // ---- sanitizeYearsInput ----

    @Test fun `years input keeps only ASCII digits`() {
        assertEquals("5", sanitizeYearsInput("5"))
        assertEquals("25", sanitizeYearsInput("25"))
    }

    @Test fun `years rejects decimal point (no fractional years)`() {
        // "5.5 years experience" → "55" — pin so the helper doesn't
        // accidentally surface "5.5" which would fail the server's
        // Int parse later.
        assertEquals("55", sanitizeYearsInput("5.5"))
    }

    @Test fun `years rejects letters and minus`() {
        assertEquals("10", sanitizeYearsInput("10 years"))
        assertEquals("10", sanitizeYearsInput("-10"))
    }

    @Test fun `years rejects Devanagari and Arabic digits`() {
        assertEquals("", sanitizeYearsInput("५"))
        assertEquals("", sanitizeYearsInput("٥"))
    }

    @Test fun `years blank yields blank`() {
        assertEquals("", sanitizeYearsInput(""))
    }
}
