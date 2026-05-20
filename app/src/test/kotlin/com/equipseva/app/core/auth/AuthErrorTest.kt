package com.equipseva.app.core.auth

import io.github.jan.supabase.auth.exception.AuthRestException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Test
import java.io.IOException

/**
 * `Throwable.toAuthError()` is the single funnel that ViewModels read into
 * the auth snackbar. A regression here either surfaces a Supabase exception
 * dump to the user (gibberish + leaks internals) or swallows a legitimate
 * "invalid credentials" into a generic "Something went wrong" so the user
 * never learns to fix their password.
 *
 * userMessage strings are part of the snackbar contract — pinning each one
 * catches accidental copy churn from a Find/Replace rename.
 */
class AuthErrorTest {

    // ---- userMessage copy (each data object is a wire-equivalent snackbar string) ----

    @Test fun `userMessage copy is pinned for InvalidCredentials`() {
        assertEquals("Email or password is incorrect.", AuthError.InvalidCredentials.userMessage)
    }

    @Test fun `userMessage copy is pinned for EmailNotConfirmed`() {
        assertEquals("Confirm your email before signing in.", AuthError.EmailNotConfirmed.userMessage)
    }

    @Test fun `userMessage copy is pinned for UserAlreadyExists`() {
        assertEquals(
            "An account with this email already exists. Try signing in.",
            AuthError.UserAlreadyExists.userMessage,
        )
    }

    @Test fun `userMessage copy is pinned for OtpExpiredOrInvalid`() {
        assertEquals(
            "That code is invalid or expired. Request a new one.",
            AuthError.OtpExpiredOrInvalid.userMessage,
        )
    }

    @Test fun `userMessage copy is pinned for RateLimited`() {
        assertEquals(
            "Too many attempts. Please wait a minute and try again.",
            AuthError.RateLimited.userMessage,
        )
    }

    @Test fun `userMessage copy is pinned for Network`() {
        assertEquals(
            "Network problem. Check your connection and retry.",
            AuthError.Network.userMessage,
        )
    }

    @Test fun `userMessage copy is pinned for Cancelled`() {
        assertEquals("Sign-in cancelled.", AuthError.Cancelled.userMessage)
    }

    @Test fun `Unknown carries its message through as the userMessage verbatim`() {
        assertEquals("anything goes", AuthError.Unknown("anything goes").userMessage)
    }

    // ---- toAuthError branches reachable without a custom AuthRestException subclass ----

    @Test fun `IOException maps to Network regardless of message`() {
        assertSame(AuthError.Network, IOException("offline").toAuthError())
        assertSame(AuthError.Network, IOException().toAuthError())
    }

    @Test fun `generic RuntimeException with a message maps to Unknown carrying that message`() {
        val out = RuntimeException("kaboom").toAuthError()
        assertEquals(AuthError.Unknown("kaboom"), out)
    }

    @Test fun `generic RuntimeException with a null message falls back to the default copy`() {
        val out = RuntimeException().toAuthError()
        assertEquals(AuthError.Unknown("Something went wrong."), out)
    }

    @Test fun `Throwable subclass (Error) falls into the generic Unknown branch`() {
        // Not RestException, not IO — anything else lands in else-> Unknown(message).
        val out = AssertionError("bad invariant").toAuthError()
        assertEquals(AuthError.Unknown("bad invariant"), out)
    }

    // ---- AuthRestException branches: hits classifyAuthRest via the real constructor ----

    private fun authRest(errorCode: String, message: String): AuthRestException =
        AuthRestException(errorCode, message, 400)

    @Test fun `invalid_credentials error code maps to InvalidCredentials`() {
        assertSame(
            AuthError.InvalidCredentials,
            authRest("invalid_credentials", "wrong pwd").toAuthError(),
        )
    }

    @Test fun `bare 'invalid login credentials' message also maps to InvalidCredentials`() {
        // Older Supabase responses skipped the error code and only set the message.
        assertSame(
            AuthError.InvalidCredentials,
            authRest("unknown_error", "Invalid login credentials").toAuthError(),
        )
    }

    @Test fun `email_not_confirmed code maps to EmailNotConfirmed`() {
        assertSame(
            AuthError.EmailNotConfirmed,
            authRest("email_not_confirmed", "verify first").toAuthError(),
        )
    }

    @Test fun `bare 'email not confirmed' message also maps to EmailNotConfirmed`() {
        assertSame(
            AuthError.EmailNotConfirmed,
            authRest("unknown_error", "Email not confirmed").toAuthError(),
        )
    }

    @Test fun `user_already_exists code maps to UserAlreadyExists`() {
        assertSame(
            AuthError.UserAlreadyExists,
            authRest("user_already_exists", "dup").toAuthError(),
        )
    }

    @Test fun `'already registered' phrase also maps to UserAlreadyExists`() {
        assertSame(
            AuthError.UserAlreadyExists,
            authRest("unknown_error", "User already registered").toAuthError(),
        )
    }

    @Test fun `otp_expired code maps to OtpExpiredOrInvalid`() {
        assertSame(
            AuthError.OtpExpiredOrInvalid,
            authRest("otp_expired", "expired").toAuthError(),
        )
    }

    @Test fun `'token has expired' message maps to OtpExpiredOrInvalid`() {
        assertSame(
            AuthError.OtpExpiredOrInvalid,
            authRest("x", "Token has expired").toAuthError(),
        )
    }

    @Test fun `'invalid otp' message maps to OtpExpiredOrInvalid`() {
        assertSame(
            AuthError.OtpExpiredOrInvalid,
            authRest("x", "Invalid OTP").toAuthError(),
        )
    }

    @Test fun `'invalid token' message maps to OtpExpiredOrInvalid`() {
        assertSame(
            AuthError.OtpExpiredOrInvalid,
            authRest("x", "Invalid token").toAuthError(),
        )
    }

    @Test fun `over_email_send_rate_limit code maps to RateLimited`() {
        assertSame(
            AuthError.RateLimited,
            authRest("over_email_send_rate_limit", "slow down").toAuthError(),
        )
    }

    @Test fun `over_request_rate_limit code maps to RateLimited`() {
        assertSame(
            AuthError.RateLimited,
            authRest("over_request_rate_limit", "slow down").toAuthError(),
        )
    }

    @Test fun `'rate limit' phrase in message also maps to RateLimited`() {
        assertSame(
            AuthError.RateLimited,
            authRest("unknown_error", "Email rate limit exceeded").toAuthError(),
        )
    }

    @Test fun `unrecognized error code falls into Unknown with the AuthRestException message`() {
        // AuthRestException stamps "Auth API error: <code>" into its message,
        // so the Unknown fallback inherits that and not the raw description.
        val out = authRest("unhandled_thing", "ignored description").toAuthError()
        val unknown = out as AuthError.Unknown
        // We don't pin the exact wrapper string — only that the wrapper kicks
        // in and we don't silently classify into one of the named buckets.
        assertEquals(true, unknown.userMessage.isNotBlank())
    }

    @Test fun `classifier is case-insensitive on both code and message`() {
        // The classifier lowercases both inputs before matching. Pin that
        // so a server stamp like "INVALID_CREDENTIALS" still resolves
        // cleanly into the InvalidCredentials bucket.
        assertSame(
            AuthError.InvalidCredentials,
            authRest("INVALID_CREDENTIALS", "WHATEVER").toAuthError(),
        )
        assertSame(
            AuthError.EmailNotConfirmed,
            authRest("unknown_error", "EMAIL NOT CONFIRMED").toAuthError(),
        )
    }
}
