package com.equipseva.app.core.auth

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.IOException

/**
 * Pins the auth-error classifier. Every sign-in / sign-up screen routes
 * exceptions through [toAuthError] and renders the resulting
 * [AuthError.userMessage]. A regression in the classifier maps a
 * recoverable failure to "Something went wrong" and breaks the user's
 * ability to self-correct (wrong password, unconfirmed email, OTP
 * expired, etc.).
 *
 * We test the underlying pure classifier [classifyAuthRestCodes]
 * directly rather than constructing a real [AuthRestException] — the
 * Supabase Auth SDK type carries an HTTP session as a constructor
 * dependency that doesn't make sense in a JVM unit test.
 */
class AuthErrorTest {

    // ---- classifyAuthRestCodes — code-based detection ----

    @Test fun `invalid_credentials code maps to InvalidCredentials`() {
        assertEquals(
            AuthError.InvalidCredentials,
            classifyAuthRestCodes(code = "invalid_credentials", message = null),
        )
    }

    @Test fun `email_not_confirmed code maps to EmailNotConfirmed`() {
        assertEquals(
            AuthError.EmailNotConfirmed,
            classifyAuthRestCodes(code = "email_not_confirmed", message = "ignored"),
        )
    }

    @Test fun `user_already_exists code maps to UserAlreadyExists`() {
        assertEquals(
            AuthError.UserAlreadyExists,
            classifyAuthRestCodes(code = "user_already_exists", message = null),
        )
    }

    @Test fun `otp_expired code maps to OtpExpiredOrInvalid`() {
        assertEquals(
            AuthError.OtpExpiredOrInvalid,
            classifyAuthRestCodes(code = "otp_expired", message = null),
        )
    }

    @Test fun `rate-limit codes map to RateLimited`() {
        assertEquals(
            AuthError.RateLimited,
            classifyAuthRestCodes(code = "over_email_send_rate_limit", message = null),
        )
        assertEquals(
            AuthError.RateLimited,
            classifyAuthRestCodes(code = "over_request_rate_limit", message = null),
        )
    }

    @Test fun `code-matching is case-insensitive`() {
        assertEquals(
            AuthError.InvalidCredentials,
            classifyAuthRestCodes(code = "INVALID_CREDENTIALS", message = null),
        )
    }

    // ---- classifyAuthRestCodes — message-based fallback ----

    @Test fun `invalid login credentials in message maps to InvalidCredentials`() {
        assertEquals(
            AuthError.InvalidCredentials,
            classifyAuthRestCodes(code = "unknown_code", message = "Invalid login credentials"),
        )
    }

    @Test fun `already registered in message maps to UserAlreadyExists`() {
        assertEquals(
            AuthError.UserAlreadyExists,
            classifyAuthRestCodes(code = null, message = "User already registered"),
        )
    }

    @Test fun `token has expired in message maps to OtpExpiredOrInvalid`() {
        assertEquals(
            AuthError.OtpExpiredOrInvalid,
            classifyAuthRestCodes(code = null, message = "Token has expired or is invalid"),
        )
    }

    @Test fun `invalid otp in message maps to OtpExpiredOrInvalid`() {
        assertEquals(
            AuthError.OtpExpiredOrInvalid,
            classifyAuthRestCodes(code = null, message = "Invalid OTP code provided"),
        )
    }

    @Test fun `rate limit in message maps to RateLimited`() {
        assertEquals(
            AuthError.RateLimited,
            classifyAuthRestCodes(code = null, message = "Email rate limit exceeded"),
        )
    }

    // ---- classifyAuthRestCodes — Unknown fallback ----

    @Test fun `unknown code falls back to Unknown wrapping the message`() {
        val out = classifyAuthRestCodes(code = "something_else", message = "Unrecognized failure")
        assertTrue(out is AuthError.Unknown)
        assertEquals("Unrecognized failure", out.userMessage)
    }

    @Test fun `unknown code with null message falls back to the canned auth-failed copy`() {
        val out = classifyAuthRestCodes(code = "wat", message = null)
        assertTrue(out is AuthError.Unknown)
        assertEquals("Authentication failed.", out.userMessage)
    }

    @Test fun `null code and null message yields the canned Unknown copy`() {
        val out = classifyAuthRestCodes(code = null, message = null)
        assertTrue(out is AuthError.Unknown)
        assertEquals("Authentication failed.", out.userMessage)
    }

    // ---- toAuthError — outer Throwable router ----

    @Test fun `IOException routes to Network`() {
        assertEquals(AuthError.Network, IOException("offline").toAuthError())
    }

    @Test fun `generic Throwable routes to Unknown wrapping its message`() {
        val out = IllegalStateException("Something exploded").toAuthError()
        assertTrue(out is AuthError.Unknown)
        assertEquals("Something exploded", out.userMessage)
    }

    @Test fun `generic Throwable with null message uses the canned generic fallback`() {
        val out = IllegalStateException().toAuthError()
        assertTrue(out is AuthError.Unknown)
        assertEquals("Something went wrong.", out.userMessage)
    }

    // ---- AuthError display copy ----

    @Test fun `userMessage strings match the pinned product copy`() {
        // The strings are user-facing and have been reviewed; a copy
        // change should be intentional, not accidental.
        assertEquals(
            "Email or password is wrong. Try Forgot password, or sign up if you don't have an account.",
            AuthError.InvalidCredentials.userMessage,
        )
        assertEquals(
            "Confirm your email before signing in.",
            AuthError.EmailNotConfirmed.userMessage,
        )
        assertEquals(
            "An account with this email already exists. Try signing in.",
            AuthError.UserAlreadyExists.userMessage,
        )
        assertEquals(
            "That code is invalid or expired. Request a new one.",
            AuthError.OtpExpiredOrInvalid.userMessage,
        )
        assertEquals(
            "Too many attempts. Please wait a minute and try again.",
            AuthError.RateLimited.userMessage,
        )
        assertEquals(
            "Network problem. Check your connection and retry.",
            AuthError.Network.userMessage,
        )
    }
}
