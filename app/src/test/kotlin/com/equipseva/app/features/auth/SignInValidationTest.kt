package com.equipseva.app.features.auth

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins the SignIn screen's inline validation. Email shape uses the
 * shared [com.equipseva.app.core.util.Validators] regex; password is
 * a presence check only (strength is a sign-up concern, not sign-in).
 */
class SignInValidationTest {

    @Test fun `valid email and non-blank password passes`() {
        val out = validateSignIn("user@example.com", "anything")
        assertNull(out.emailError)
        assertNull(out.passwordError)
    }

    @Test fun `bad email shape is flagged`() {
        val out = validateSignIn("not-an-email", "anything")
        assertEquals("Enter a valid email", out.emailError)
        assertNull(out.passwordError)
    }

    @Test fun `blank password is flagged independently`() {
        val out = validateSignIn("user@example.com", "")
        assertNull(out.emailError)
        assertEquals("Password is required", out.passwordError)
    }

    @Test fun `whitespace-only password is treated as blank`() {
        val out = validateSignIn("user@example.com", "   ")
        assertEquals("Password is required", out.passwordError)
    }

    @Test fun `both errors surface when both inputs are bad`() {
        val out = validateSignIn("", "")
        assertEquals("Enter a valid email", out.emailError)
        assertEquals("Password is required", out.passwordError)
    }

    @Test fun `sign-in does NOT enforce password strength`() {
        // Deliberately permissive — letting a weak password through here
        // is fine because (a) the server already rejects bad creds, and
        // (b) requiring strength on sign-in locks legacy users out.
        val out = validateSignIn("user@example.com", "x")
        assertNull(out.passwordError)
    }
}
