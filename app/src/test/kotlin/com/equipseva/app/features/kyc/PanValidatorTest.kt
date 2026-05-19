package com.equipseva.app.features.kyc

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

// Round 423 — PanValidator is the client-side gate before KYC submit.
// The 5-letter / 4-digit / 1-letter regex is brittle and easy to
// regress (e.g. someone "helpfully" adds case-insensitive flag or
// trims) — these tests pin every observable corner.
class PanValidatorTest {

    @Test fun `canonical PAN is valid`() {
        assertTrue(PanValidator.isValid("ABCDE1234F"))
    }

    @Test fun `lowercase is not normalised — must already be uppercase`() {
        // Regex is `^[A-Z]{5}[0-9]{4}[A-Z]$` — case-sensitive on purpose.
        // Caller is expected to .uppercase() before validating; if they
        // don't, this returns false rather than silently accepting.
        assertFalse(PanValidator.isValid("abcde1234f"))
    }

    @Test fun `leading or trailing whitespace fails`() {
        assertFalse(PanValidator.isValid(" ABCDE1234F"))
        assertFalse(PanValidator.isValid("ABCDE1234F "))
        assertFalse(PanValidator.isValid("\tABCDE1234F"))
    }

    @Test fun `too short fails`() {
        assertFalse(PanValidator.isValid(""))
        assertFalse(PanValidator.isValid("ABCDE1234"))
        assertFalse(PanValidator.isValid("ABC"))
    }

    @Test fun `too long fails`() {
        assertFalse(PanValidator.isValid("ABCDE1234FX"))
        assertFalse(PanValidator.isValid("ABCDE12345F"))
    }

    @Test fun `digit in letter position fails`() {
        assertFalse(PanValidator.isValid("AB1DE1234F"))
        assertFalse(PanValidator.isValid("ABCDE1234F".replaceRange(9, 10, "1")))
    }

    @Test fun `letter in digit position fails`() {
        assertFalse(PanValidator.isValid("ABCDEA234F"))
        assertFalse(PanValidator.isValid("ABCDE123AF"))
    }

    @Test fun `non-ascii chars fail`() {
        assertFalse(PanValidator.isValid("ABCDÉ1234F"))
        assertFalse(PanValidator.isValid("ABCDE१२३४F")) // Devanagari digits
    }

    @Test fun `special characters fail`() {
        assertFalse(PanValidator.isValid("ABCDE-1234F"))
        assertFalse(PanValidator.isValid("ABCDE.1234F"))
        assertFalse(PanValidator.isValid("ABCDE 1234F"))
    }
}
