package com.equipseva.app.features.security

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the change-email form's inline validator. Two-field gate
 * (current password + new email). The password is the re-auth proof,
 * not a strength gate — blank-check only — so a thief with an
 * unlocked phone can't quietly redirect KYC mail to themselves but
 * the legitimate user can re-confirm with whatever password they
 * already set.
 */
class ChangeEmailValidatorTest {

    @Test fun `happy path yields no errors`() {
        val errors = validateChangeEmail(
            currentPassword = "Secret123",
            newEmail = "new@example.com",
        )
        assertNull(errors.passwordError)
        assertNull(errors.emailError)
        assertFalse(errors.hasAny)
    }

    // ---- password ----

    @Test fun `blank password yields canned password error`() {
        val errors = validateChangeEmail("", "new@example.com")
        assertEquals("Enter your current password", errors.passwordError)
    }

    @Test fun `whitespace-only password is treated as blank`() {
        val errors = validateChangeEmail("   ", "new@example.com")
        assertEquals("Enter your current password", errors.passwordError)
    }

    @Test fun `validator does NOT gate on password strength here`() {
        // Re-auth proof, not a strength check — accept whatever the
        // user set originally so a legitimate flow doesn't fail
        // because their password predates the current strength rules.
        val errors = validateChangeEmail("x", "new@example.com")
        assertNull(errors.passwordError)
    }

    // ---- email ----

    @Test fun `blank email yields the canned new-email error`() {
        val errors = validateChangeEmail("Secret123", "")
        assertEquals("Enter your new email", errors.emailError)
    }

    @Test fun `whitespace-only email is treated as blank after trim`() {
        val errors = validateChangeEmail("Secret123", "   ")
        assertEquals("Enter your new email", errors.emailError)
    }

    @Test fun `malformed email yields the invalid-email error`() {
        val errors = validateChangeEmail("Secret123", "not-an-email")
        assertEquals("Enter a valid email address", errors.emailError)
    }

    @Test fun `leading-trailing spaces are trimmed before validating`() {
        // Validators.emailIsValid already trims internally; pin so a
        // refactor that drops trim doesn't surface ghost-error on
        // paste-padded input.
        val errors = validateChangeEmail("Secret123", "  new@example.com  ")
        assertNull(errors.emailError)
    }

    // ---- both ----

    @Test fun `both blank yields both errors at once (no short-circuit)`() {
        val errors = validateChangeEmail("", "")
        assertEquals("Enter your current password", errors.passwordError)
        assertEquals("Enter your new email", errors.emailError)
        assertTrue(errors.hasAny)
    }
}
