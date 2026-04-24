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

    @Test fun `otp accepts 6 to 10 digits`() {
        assertTrue(Validators.otpIsValid("123456"))
        assertTrue(Validators.otpIsValid("1234567890"))
    }

    @Test fun `otp rejects wrong length or non-digits`() {
        assertFalse(Validators.otpIsValid("12345"))
        assertFalse(Validators.otpIsValid("12345678901"))
        assertFalse(Validators.otpIsValid("12345a"))
    }
}
