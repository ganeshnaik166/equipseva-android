package com.equipseva.app.features.kyc

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * PAN shape-check (5 uppercase letters + 4 digits + 1 uppercase letter).
 * Client-side guard against typos — actual issuance check is admin-side
 * pending Karza/Sandbox PAN-verify integration (v1.1).
 */
class PanValidatorTest {

    @Test fun `canonical PAN format is accepted`() {
        assertTrue(PanValidator.isValid("ABCDE1234F"))
        assertTrue(PanValidator.isValid("ZZZZZ9999Z"))
    }

    @Test fun `lowercase letters are rejected`() {
        // The PAN field auto-uppercases on Step 2, but the validator must
        // stay strict so a lowercased input from autofill (or paste) doesn't
        // sneak past.
        assertFalse(PanValidator.isValid("abcde1234f"))
        assertFalse(PanValidator.isValid("ABCDe1234F"))
    }

    @Test fun `wrong length is rejected`() {
        assertFalse(PanValidator.isValid(""))
        assertFalse(PanValidator.isValid("ABCDE1234"))
        assertFalse(PanValidator.isValid("ABCDE1234FG"))
    }

    @Test fun `wrong char shape is rejected`() {
        // 5 letters + 4 digits + 1 letter — every other position arrangement
        // fails. Cover a handful of bad shapes.
        assertFalse(PanValidator.isValid("12345ABCDE"))
        assertFalse(PanValidator.isValid("ABCDE12345"))
        assertFalse(PanValidator.isValid("ABCD12345F"))
        assertFalse(PanValidator.isValid("ABCDEFGHIJ"))
    }

    @Test fun `whitespace or punctuation is rejected`() {
        assertFalse(PanValidator.isValid(" ABCDE1234F"))
        assertFalse(PanValidator.isValid("ABCDE 1234F"))
        assertFalse(PanValidator.isValid("ABCDE-1234F"))
    }
}
