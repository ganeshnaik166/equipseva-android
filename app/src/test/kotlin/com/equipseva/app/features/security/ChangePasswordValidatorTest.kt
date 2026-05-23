package com.equipseva.app.features.security

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the change-password form's inline validator. Three-field gate
 * with one cross-field rule (new != current). Caught regions:
 *
 *   1) New password shares the SignUp strength policy (length + has
 *      letter + has digit) — earlier code only length-checked, letting
 *      through "aaaaaaaa" / "12345678". Pin so we never regress to
 *      that.
 *   2) "Same as current" is a distinct error from "weak password" —
 *      pin so a refactor doesn't silently swap the two messages.
 *   3) Confirm-match runs AFTER blank check so blank confirm doesn't
 *      surface as a "doesn't match" error.
 */
class ChangePasswordValidatorTest {

    @Test fun `happy path yields no errors`() {
        val errors = validateChangePassword(
            currentPassword = "OldSecret123",
            newPassword = "NewSecret456",
            confirmPassword = "NewSecret456",
        )
        assertNull(errors.currentPasswordError)
        assertNull(errors.newPasswordError)
        assertNull(errors.confirmPasswordError)
        assertFalse(errors.hasAny)
    }

    // ---- current password ----

    @Test fun `blank current password yields canned error`() {
        val errors = validateChangePassword("", "NewSecret456", "NewSecret456")
        assertEquals("Enter your current password", errors.currentPasswordError)
    }

    @Test fun `whitespace-only current password is treated as blank`() {
        val errors = validateChangePassword("   ", "NewSecret456", "NewSecret456")
        assertEquals("Enter your current password", errors.currentPasswordError)
    }

    // ---- new password ----

    @Test fun `blank new password yields canned new-password error`() {
        val errors = validateChangePassword("OldSecret123", "", "")
        assertEquals("Enter a new password", errors.newPasswordError)
    }

    @Test fun `new password equal to current yields the differ-from-current error`() {
        // This check sits before the strength gate — even a weak
        // matching password surfaces the equality message first so
        // users know what they need to fix.
        val errors = validateChangePassword(
            currentPassword = "Secret123",
            newPassword = "Secret123",
            confirmPassword = "Secret123",
        )
        assertEquals(
            "Choose a password different from your current one",
            errors.newPasswordError,
        )
    }

    @Test fun `weak new password yields a passwordWeakness error`() {
        // 7 chars — below the SignUp gate's 8-char minimum.
        val errors = validateChangePassword(
            currentPassword = "OldSecret123",
            newPassword = "abc123",
            confirmPassword = "abc123",
        )
        assertEquals("Use at least 8 characters", errors.newPasswordError)
    }

    @Test fun `new password without letters fails strength check (no regression to letters-optional)`() {
        // "aaaaaaaa" and "12345678" used to slip through the
        // length-only gate — pin so the shared Validators policy
        // catches them.
        val noLetters = validateChangePassword(
            currentPassword = "OldSecret123",
            newPassword = "12345678",
            confirmPassword = "12345678",
        )
        assertEquals("Include at least one letter", noLetters.newPasswordError)

        val noDigits = validateChangePassword(
            currentPassword = "OldSecret123",
            newPassword = "aaaaaaaa",
            confirmPassword = "aaaaaaaa",
        )
        assertEquals("Include at least one number", noDigits.newPasswordError)
    }

    // ---- confirm password ----

    @Test fun `blank confirm yields the re-enter copy (not mismatch)`() {
        // Order matters — blank should win over "doesn't match".
        val errors = validateChangePassword(
            currentPassword = "OldSecret123",
            newPassword = "NewSecret456",
            confirmPassword = "",
        )
        assertEquals("Re-enter your new password", errors.confirmPasswordError)
    }

    @Test fun `mismatching confirm yields the doesn't-match copy`() {
        val errors = validateChangePassword(
            currentPassword = "OldSecret123",
            newPassword = "NewSecret456",
            confirmPassword = "DifferentSecret789",
        )
        assertEquals("Passwords don't match", errors.confirmPasswordError)
    }

    // ---- composite ----

    @Test fun `all three fields blank yields all three field errors at once`() {
        val errors = validateChangePassword("", "", "")
        assertEquals("Enter your current password", errors.currentPasswordError)
        assertEquals("Enter a new password", errors.newPasswordError)
        assertEquals("Re-enter your new password", errors.confirmPasswordError)
        assertTrue(errors.hasAny)
    }
}
