package com.equipseva.app.core.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ValidatorsTest {

    @Test fun `email accepts typical formats`() {
        assertTrue(Validators.emailIsValid("user@example.com"))
        assertTrue(Validators.emailIsValid("first.last+tag@sub.example.co"))
        assertTrue(Validators.emailIsValid("  user@example.com  "))
    }

    @Test fun `email rejects missing at, missing dot, or short tld`() {
        assertFalse(Validators.emailIsValid(""))
        assertFalse(Validators.emailIsValid("no-at-sign.com"))
        assertFalse(Validators.emailIsValid("user@nodot"))
        assertFalse(Validators.emailIsValid("user@x.c"))
    }

    @Test fun `email rejects malformed domain label boundaries`() {
        // Round 236 tightening: the old domain regex `[A-Za-z0-9.-]+\.[A-Za-z]{2,}`
        // accepted leading-dot / leading-hyphen garbage that Postgres stored
        // verbatim. The per-label shape now rejects each of these explicitly.
        assertFalse(Validators.emailIsValid("user@.com"))
        assertFalse(Validators.emailIsValid("user@-foo.com"))
        assertFalse(Validators.emailIsValid("user@foo-.com"))
        assertFalse(Validators.emailIsValid("user@foo..com"))
    }

    @Test fun `password needs 8+ chars with letter and digit`() {
        assertTrue(Validators.passwordIsStrong("Password1"))
        assertTrue(Validators.passwordIsStrong("abcd1234"))
    }

    @Test fun `password rejects short, letterless, digitless`() {
        assertFalse(Validators.passwordIsStrong("Pass1"))
        assertFalse(Validators.passwordIsStrong("12345678"))
        assertFalse(Validators.passwordIsStrong("abcdefgh"))
    }

    @Test fun `password weakness explains the first missing requirement`() {
        assertEquals("Use at least 8 characters", Validators.passwordWeakness("abc1"))
        assertEquals("Include at least one letter", Validators.passwordWeakness("12345678"))
        assertEquals("Include at least one number", Validators.passwordWeakness("abcdefgh"))
        assertNull(Validators.passwordWeakness("Password1"))
    }

    @Test fun `gstin accepts canonical 15-char format`() {
        assertNull(Validators.gstinError("22ABCDE1234F1Z5"))
        assertNull(Validators.gstinError("07AAACT2727Q1ZW"))
        assertNull(Validators.gstinError("  22ABCDE1234F1Z5  "))
        assertNull(Validators.gstinError("22abcde1234f1z5")) // lower-case is normalized
    }

    @Test fun `gstin empty is treated as not-required at this layer`() {
        assertNull(Validators.gstinError(""))
        assertNull(Validators.gstinError("   "))
    }

    @Test fun `gstin rejects wrong length`() {
        assertEquals("GSTIN must be exactly 15 characters", Validators.gstinError("22ABCDE1234"))
        assertEquals("GSTIN must be exactly 15 characters", Validators.gstinError("22ABCDE1234F1Z5X"))
    }

    @Test fun `gstin rejects malformed 15-char strings`() {
        // State code out of range (40), 13th digit not letter, missing Z separator.
        assertEquals("Invalid GSTIN format", Validators.gstinError("40ABCDE1234F1Z5"))
        assertEquals("Invalid GSTIN format", Validators.gstinError("22ABCDE12345115"))
        assertEquals("Invalid GSTIN format", Validators.gstinError("22abcde1234fAA5".uppercase()))
    }

    // Round 441 — indiaMobileError validator
    @Test fun `india mobile empty is treated as not-required`() {
        assertNull(Validators.indiaMobileError(""))
        assertNull(Validators.indiaMobileError("   "))
    }

    @Test fun `india mobile accepts 10 digits starting 6-9`() {
        assertNull(Validators.indiaMobileError("9876543210"))
        assertNull(Validators.indiaMobileError("6000000000"))
        assertNull(Validators.indiaMobileError("8123456789"))
    }

    @Test fun `india mobile accepts +91 and 91 prefixes`() {
        assertNull(Validators.indiaMobileError("+919876543210"))
        assertNull(Validators.indiaMobileError("919876543210"))
        assertNull(Validators.indiaMobileError("  +91 98765 43210 "))
    }

    @Test fun `india mobile rejects 10 digits starting 1-5 or 0`() {
        // Indian mobile range is 6-9 per TRAI numbering plan.
        assertEquals("Indian mobile must start with 6, 7, 8, or 9", Validators.indiaMobileError("1234567890"))
        assertEquals("Indian mobile must start with 6, 7, 8, or 9", Validators.indiaMobileError("5876543210"))
        assertEquals("Indian mobile must start with 6, 7, 8, or 9", Validators.indiaMobileError("0876543210"))
    }

    @Test fun `india mobile rejects wrong digit count`() {
        assertEquals("Enter 10 digits", Validators.indiaMobileError("12345"))
        assertEquals("Enter 10 digits", Validators.indiaMobileError("98765432101"))
    }

    // Round 441 — pincodeError validator
    @Test fun `pincode empty is treated as not-required`() {
        assertNull(Validators.pincodeError(""))
        assertNull(Validators.pincodeError("   "))
    }

    @Test fun `pincode accepts 6 digits starting 1-9`() {
        assertNull(Validators.pincodeError("110001")) // New Delhi
        assertNull(Validators.pincodeError("500001")) // Hyderabad
        assertNull(Validators.pincodeError("999999"))
    }

    @Test fun `pincode rejects 6 digits starting 0`() {
        assertEquals("Invalid PIN code", Validators.pincodeError("012345"))
    }

    @Test fun `pincode rejects wrong length`() {
        assertEquals("PIN code must be exactly 6 digits", Validators.pincodeError("12345"))
        assertEquals("PIN code must be exactly 6 digits", Validators.pincodeError("1234567"))
    }

    @Test fun `pincode rejects non-digit chars`() {
        assertEquals("Invalid PIN code", Validators.pincodeError("1100AB"))
    }
}
