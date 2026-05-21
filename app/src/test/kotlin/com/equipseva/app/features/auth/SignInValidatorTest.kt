package com.equipseva.app.features.auth

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the sign-in form's inline validator. The error copy is
 * user-facing and matches the placeholder hints on the SignIn screen;
 * pin so a copy tweak is intentional.
 */
class SignInValidatorTest {

    @Test fun `valid email + non-blank password yields no errors`() {
        val errors = validateSignIn("ravi@x.in", "Secret123!")
        assertNull(errors.emailError)
        assertNull(errors.passwordError)
        assertFalse(errors.hasAny)
    }

    @Test fun `invalid email yields the canned email error`() {
        val errors = validateSignIn("not-an-email", "Secret123!")
        assertEquals("Enter a valid email", errors.emailError)
        assertNull(errors.passwordError)
        assertTrue(errors.hasAny)
    }

    @Test fun `blank email yields the canned email error`() {
        val errors = validateSignIn("  ", "Secret123!")
        assertEquals("Enter a valid email", errors.emailError)
    }

    @Test fun `blank password yields the canned password error`() {
        val errors = validateSignIn("ravi@x.in", "  ")
        assertNull(errors.emailError)
        assertEquals("Password is required", errors.passwordError)
        assertTrue(errors.hasAny)
    }

    @Test fun `empty password yields the canned password error`() {
        val errors = validateSignIn("ravi@x.in", "")
        assertEquals("Password is required", errors.passwordError)
    }

    @Test fun `both invalid yields both errors at once (no short-circuit)`() {
        // Pinning that validateSignIn is NOT a fail-fast — both fields
        // get their inline error in a single pass so the user sees the
        // full picture rather than fixing email and then discovering
        // password is also empty.
        val errors = validateSignIn("nope", "")
        assertEquals("Enter a valid email", errors.emailError)
        assertEquals("Password is required", errors.passwordError)
        assertTrue(errors.hasAny)
    }

    @Test fun `password validator does not gate on strength here — only non-blank`() {
        // SignIn lets weak / short passwords through to the server; the
        // strength gate lives on Sign Up only. Pin so a future
        // "tighten password on sign-in too" change is reviewed.
        val errors = validateSignIn("ravi@x.in", "x")
        assertNull(errors.passwordError)
    }

    @Test fun `email validator tolerates leading spaces (Validators trims internally)`() {
        // Validators.emailIsValid does `.trim()` on the input before
        // running the regex, so a leading-space paste validates as
        // long as the inner address is well-formed. Pin so a future
        // "stricter inline error for whitespace" change is reviewed.
        val errors = validateSignIn("  ravi@x.in", "Secret")
        assertNull(errors.emailError)
    }
}
