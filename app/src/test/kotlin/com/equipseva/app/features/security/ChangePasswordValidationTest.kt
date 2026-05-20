package com.equipseva.app.features.security

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins every branch of the change-password inline validation. A
 * regression here either lets a blank / too-short / matching-current
 * password through to the Supabase updatePassword call (which fails
 * server-side with a confusing error), or it locks the user out of a
 * legitimate change by surfacing a stale error.
 */
class ChangePasswordValidationTest {

    @Test fun `happy path returns no errors`() {
        val out = validateChangePassword(
            currentPwd = "OldPass1",
            newPwd = "NewPass1",
            confirmPwd = "NewPass1",
        )
        assertNull(out.currentPasswordError)
        assertNull(out.newPasswordError)
        assertNull(out.confirmPasswordError)
    }

    @Test fun `blank current password is flagged`() {
        val out = validateChangePassword("", "NewPass1", "NewPass1")
        assertEquals("Enter your current password", out.currentPasswordError)
    }

    @Test fun `whitespace-only current password is flagged as blank`() {
        val out = validateChangePassword("   ", "NewPass1", "NewPass1")
        assertEquals("Enter your current password", out.currentPasswordError)
    }

    @Test fun `blank new password is flagged before length`() {
        val out = validateChangePassword("OldPass1", "", "")
        assertEquals("Enter a new password", out.newPasswordError)
    }

    @Test fun `short new password is flagged with the min-length copy`() {
        val out = validateChangePassword("OldPass1", "short", "short")
        assertEquals(
            "Use at least ${ChangePasswordViewModel.MIN_PASSWORD_LENGTH} characters",
            out.newPasswordError,
        )
    }

    @Test fun `new password equal to current is flagged`() {
        // Otherwise the user thinks they "changed" their password but
        // nothing about the auth state actually rotated.
        val out = validateChangePassword(
            currentPwd = "SamePass1",
            newPwd = "SamePass1",
            confirmPwd = "SamePass1",
        )
        assertEquals(
            "Choose a password different from your current one",
            out.newPasswordError,
        )
    }

    @Test fun `confirm blank is flagged`() {
        val out = validateChangePassword("OldPass1", "NewPass1", "")
        assertEquals("Re-enter your new password", out.confirmPasswordError)
    }

    @Test fun `confirm mismatch is flagged`() {
        val out = validateChangePassword("OldPass1", "NewPass1", "NewPass2")
        assertEquals("Passwords don't match", out.confirmPasswordError)
    }

    @Test fun `all three errors surface independently when every input is bad`() {
        val out = validateChangePassword("", "x", "")
        assertEquals("Enter your current password", out.currentPasswordError)
        assertEquals(
            "Use at least ${ChangePasswordViewModel.MIN_PASSWORD_LENGTH} characters",
            out.newPasswordError,
        )
        assertEquals("Re-enter your new password", out.confirmPasswordError)
    }

    @Test fun `min-length constant matches Validators floor for consistency`() {
        // Both surfaces enforce 8+; pinning the constant means a bump in
        // one place will be caught here even if the other isn't bumped.
        assertEquals(8, ChangePasswordViewModel.MIN_PASSWORD_LENGTH)
    }
}
