package com.equipseva.app.features.auth

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the sign-up form's inline validator. Four independent gates
 * (name, email, password, role); the error copy is user-facing and
 * has been reviewed by product. A regression in any branch would
 * either let invalid data through to the auth RPC (server-side
 * rejection with a generic "create account failed" toast) or
 * over-gate a happy path.
 */
class SignUpValidatorTest {

    @Test fun `happy path yields no errors`() {
        val errors = validateSignUp(
            fullName = "Ravi Kumar",
            email = "ravi@x.in",
            password = "Secret123!",
            role = UserRole.HOSPITAL,
        )
        assertNull(errors.fullNameError)
        assertNull(errors.emailError)
        assertNull(errors.passwordError)
        assertFalse(errors.roleMissing)
        assertFalse(errors.hasAny)
    }

    // ---- name ----

    @Test fun `name too short yields canned error`() {
        val errors = validateSignUp("R", "ravi@x.in", "Secret123", UserRole.HOSPITAL)
        assertEquals("Enter your full name", errors.fullNameError)
    }

    @Test fun `name with no letters yields canned letters-required error`() {
        // Pure punctuation / digits / emoji shouldn't pass — Postgres
        // stores them as-is and they surface as garbage in cards.
        val errors = validateSignUp("12 34", "ravi@x.in", "Secret123", UserRole.HOSPITAL)
        assertEquals("Enter a valid name (letters required)", errors.fullNameError)
    }

    @Test fun `name with leading-trailing spaces still passes when trimmed length is sufficient`() {
        val errors = validateSignUp("  Ravi  ", "ravi@x.in", "Secret123", UserRole.HOSPITAL)
        assertNull(errors.fullNameError)
    }

    // ---- email ----

    @Test fun `invalid email yields canned email error`() {
        val errors = validateSignUp("Ravi", "nope", "Secret123", UserRole.HOSPITAL)
        assertEquals("Enter a valid email", errors.emailError)
    }

    // ---- password ----

    @Test fun `short password yields length error`() {
        val errors = validateSignUp("Ravi", "ravi@x.in", "abc1", UserRole.HOSPITAL)
        assertEquals("Use at least 8 characters", errors.passwordError)
    }

    @Test fun `password missing letter yields letter error`() {
        val errors = validateSignUp("Ravi", "ravi@x.in", "12345678", UserRole.HOSPITAL)
        assertEquals("Include at least one letter", errors.passwordError)
    }

    @Test fun `password missing digit yields digit error`() {
        val errors = validateSignUp("Ravi", "ravi@x.in", "abcdefgh", UserRole.HOSPITAL)
        assertEquals("Include at least one number", errors.passwordError)
    }

    // ---- role ----

    @Test fun `null role yields roleMissing flag (not a field error)`() {
        // Role is surfaced via the form-level banner, not as an
        // inline field error — that's why it's a Boolean flag rather
        // than a string.
        val errors = validateSignUp("Ravi", "ravi@x.in", "Secret123", role = null)
        assertTrue(errors.roleMissing)
        assertTrue(errors.hasAny)
    }

    @Test fun `roleMissing alone is enough to fail hasAny`() {
        // Even when name/email/password are valid, missing role blocks.
        val errors = validateSignUp("Ravi", "ravi@x.in", "Secret123", role = null)
        assertNull(errors.fullNameError)
        assertNull(errors.emailError)
        assertNull(errors.passwordError)
        assertTrue(errors.hasAny)
    }

    // ---- multi-field ----

    @Test fun `every field invalid yields every field error (no short-circuit)`() {
        val errors = validateSignUp("", "nope", "abc", role = null)
        assertEquals("Enter your full name", errors.fullNameError)
        assertEquals("Enter a valid email", errors.emailError)
        assertEquals("Use at least 8 characters", errors.passwordError)
        assertTrue(errors.roleMissing)
        assertTrue(errors.hasAny)
    }
}
