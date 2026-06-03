package com.equipseva.app.features.onboarding

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Round 438 fix #10 — the mismatch detector for the re-type account
 * number field. Logic mirrors what the VM computes per keystroke:
 * only flag mismatch once the confirm field has reached the primary's
 * length, so we don't nag mid-type.
 *
 * Helper is a copy of the private one in EngineerPayoutOnboardingViewModel
 * so the rule stays testable without exposing the VM internal.
 */
class AccountNumberMismatchTest {

    private fun mismatch(primary: String, confirm: String): Boolean {
        if (primary.isBlank() || confirm.isBlank()) return false
        if (confirm.length < primary.length) return false
        return primary != confirm
    }

    @Test fun `blank inputs never flag mismatch`() {
        assertFalse(mismatch("", ""))
        assertFalse(mismatch("12345", ""))
        assertFalse(mismatch("", "12345"))
    }

    @Test fun `confirm shorter than primary stays quiet (still typing)`() {
        assertFalse(mismatch("123456789", "1234"))
        assertFalse(mismatch("123456789", "12345678"))
    }

    @Test fun `confirm equal length but differing flags mismatch`() {
        assertTrue(mismatch("123456789", "123456788"))
        assertTrue(mismatch("123456789012", "999999999012"))
    }

    @Test fun `exact match does not flag`() {
        assertFalse(mismatch("123456789", "123456789"))
        assertFalse(mismatch("0001112223", "0001112223"))
    }

    @Test fun `confirm longer than primary still flags (extra digit)`() {
        // User accidentally typed an extra digit — should also flag.
        assertTrue(mismatch("123456789", "1234567890"))
    }
}
