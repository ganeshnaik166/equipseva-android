package com.equipseva.app.features.kyc

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The Verhoeff check on the trailing digit is the only cheap pre-flight we
 * have against typo'd Aadhaar numbers — server-side e-Aadhaar verification
 * is deferred until v1.1. Pin every documented branch so a regression
 * doesn't quietly start letting bad numbers into the submission queue.
 */
class AadhaarValidatorTest {

    @Test fun `valid 12-digit Aadhaar with passing Verhoeff is accepted`() {
        // UIDAI public test number — the Verhoeff check passes by design.
        assertTrue(AadhaarValidator.isValid("234123412346"))
    }

    @Test fun `wrong length is rejected`() {
        assertFalse(AadhaarValidator.isValid(""))
        assertFalse(AadhaarValidator.isValid("23412341234"))
        assertFalse(AadhaarValidator.isValid("2341234123456"))
    }

    @Test fun `non-digit characters are rejected`() {
        assertFalse(AadhaarValidator.isValid("23412341234A"))
        assertFalse(AadhaarValidator.isValid("2341 2341 2346"))
        assertFalse(AadhaarValidator.isValid("2341-2341-2346"))
    }

    @Test fun `leading 0 or 1 is rejected per UIDAI spec`() {
        // Real Aadhaar never starts with 0 or 1 — the issuance pool excludes
        // those leading digits. Reject them client-side too.
        assertFalse(AadhaarValidator.isValid("034123412345"))
        assertFalse(AadhaarValidator.isValid("134123412345"))
    }

    @Test fun `wrong Verhoeff check digit is rejected`() {
        // Bump the last digit of the known-good test number — Verhoeff should
        // refuse it.
        assertFalse(AadhaarValidator.isValid("234123412347"))
        assertFalse(AadhaarValidator.isValid("234123412345"))
    }

    @Test fun `all-zeros fails on the leading-zero rule`() {
        assertFalse(AadhaarValidator.isValid("000000000000"))
    }
}
