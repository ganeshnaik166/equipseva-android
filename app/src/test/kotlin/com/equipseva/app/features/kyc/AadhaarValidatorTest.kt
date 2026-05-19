package com.equipseva.app.features.kyc

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

// Round 423 — AadhaarValidator implements the UIDAI-mandated Verhoeff
// checksum over 12 digits. It's the cheapest local guard against typos
// and obviously-fake numbers; a regression here would let bad Aadhaars
// flow into kyc_docs storage + admin review queue. The matrix lookup
// tables + reverse iteration + modulo-8 index are easy to break in a
// "small cleanup" PR, so pin every observable corner.
//
// Aadhaar numbers below are synthetic (random + Verhoeff-checked) and
// not assigned to any real person.
class AadhaarValidatorTest {

    // ---------------------------------------------------------------------
    //  Length / shape rejections (cheap fast-fails before checksum)
    // ---------------------------------------------------------------------

    @Test fun `empty input is invalid`() {
        assertFalse(AadhaarValidator.isValid(""))
    }

    @Test fun `length less than 12 is invalid`() {
        assertFalse(AadhaarValidator.isValid("12345"))
        assertFalse(AadhaarValidator.isValid("23456789012")) // 11 digits
    }

    @Test fun `length greater than 12 is invalid`() {
        assertFalse(AadhaarValidator.isValid("2345678901234")) // 13 digits
    }

    @Test fun `non-ascii digits are rejected`() {
        // Devanagari numerals are accepted by Char.isDigit() but the
        // checksum arithmetic (n = d - '0') would compute out-of-range
        // indices. The validator pre-filters via the in-range check.
        assertFalse(AadhaarValidator.isValid("२३४५६७८९०१२३"))
    }

    @Test fun `letters and special chars are rejected`() {
        assertFalse(AadhaarValidator.isValid("A23456789012"))
        assertFalse(AadhaarValidator.isValid("234567 89012"))
        assertFalse(AadhaarValidator.isValid("234-567-8901"))
    }

    // ---------------------------------------------------------------------
    //  Aadhaar spec — first digit can't be 0 or 1
    // ---------------------------------------------------------------------

    @Test fun `leading zero is rejected even if checksum matches`() {
        // 12-digit string of zeros has a trivially valid Verhoeff checksum
        // (c=0 stays 0 through every multiplication), but UIDAI doesn't
        // issue numbers starting with 0. Pin the spec-level rejection.
        assertFalse(AadhaarValidator.isValid("000000000000"))
    }

    @Test fun `leading 1 is rejected per UIDAI spec`() {
        // 12-digit "1xxxxxxxx" must be rejected before checksum runs.
        // We use the all-zeros-after-leading-1 pattern; checksum value
        // is incidental.
        assertFalse(AadhaarValidator.isValid("100000000000"))
    }

    // ---------------------------------------------------------------------
    //  Checksum behavior — flip last digit & assert rejection
    // ---------------------------------------------------------------------

    @Test fun `valid synthetic aadhaar passes`() {
        // 234567890124 — the Verhoeff check digit for 23456789012 is 4.
        // (Computable by hand from the d/p tables in AadhaarValidator.)
        assertTrue(AadhaarValidator.isValid("234567890124"))
    }

    @Test fun `flipping the check digit fails`() {
        // Same prefix, last digit wrong by one → checksum fails.
        assertFalse(AadhaarValidator.isValid("234567890123"))
        assertFalse(AadhaarValidator.isValid("234567890125"))
    }

    @Test fun `permuting two digits in the middle breaks checksum`() {
        // Verhoeff catches single-digit substitutions AND adjacent
        // transpositions — the standard test for the algorithm.
        // 234567890124 valid → swap pos 2 and 3 = 243567890124 invalid.
        assertTrue(AadhaarValidator.isValid("234567890124"))
        assertFalse(AadhaarValidator.isValid("243567890124"))
    }

    @Test fun `algorithm rejects nine-of-eleven-substitutions of a valid number`() {
        // Property test: take a known-valid 12-digit Aadhaar and change
        // each non-leading digit by +1 (mod 10). Verhoeff is designed to
        // catch every single-digit substitution, so all permutations must
        // reject.
        val valid = "234567890124"
        assertTrue(AadhaarValidator.isValid(valid))
        for (i in 1..11) {
            val flipped = StringBuilder(valid)
            val ch = flipped[i]
            // Pick a different digit for this position to ensure the value
            // actually changes (e.g. '9'→'0', '0'→'1', else +1 mod 10).
            val newChar = if (ch == '9') '0' else ('0' + ((ch - '0' + 1) % 10))
            flipped[i] = newChar
            assertFalse(
                "substitution at index $i: $valid → $flipped should fail",
                AadhaarValidator.isValid(flipped.toString()),
            )
        }
    }
}
