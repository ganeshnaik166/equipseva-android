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
}
