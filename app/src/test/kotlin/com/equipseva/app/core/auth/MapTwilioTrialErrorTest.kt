package com.equipseva.app.core.auth

import org.junit.Assert.assertNotSame
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the Twilio trial-mode error translation. Three signals trip
 * the rewrite (any one is enough), all case-insensitive, and the
 * detection looks at both the throwable's own message AND its
 * cause's message so a Supabase wrapper around the underlying
 * Twilio error still gets recognised.
 *
 * When no trial signal is found, the original throwable is returned
 * unchanged so Crashlytics still sees the underlying exception class
 * + stack.
 */
class MapTwilioTrialErrorTest {

    @Test fun `Twilio 21608 code triggers the friendly rewrite`() {
        val original = RuntimeException("Twilio error 21608: unverified destination")
        val mapped = mapTwilioTrialError(original)
        assertNotSame(original, mapped)
        assertTrue(
            "expected friendly trial copy in: ${mapped.message}",
            mapped.message?.contains("trial mode", ignoreCase = true) == true,
        )
    }

    @Test fun `unverified plus twilio words trigger the rewrite`() {
        // Catches Supabase wrappers that rephrase the underlying error.
        val original = RuntimeException("Supabase Twilio gateway: destination is unverified")
        val mapped = mapTwilioTrialError(original)
        assertNotSame(original, mapped)
    }

    @Test fun `trial plus verified words trigger the rewrite (human-readable Twilio copy)`() {
        val original = RuntimeException("Your trial account can only send to verified numbers")
        val mapped = mapTwilioTrialError(original)
        assertNotSame(original, mapped)
    }

    @Test fun `detection reads the cause chain when the outer message is empty`() {
        // Supabase Auth wraps the underlying Twilio HTTP error as a
        // cause; the outer message is the generic "auth call failed".
        // Pin so the chain-walk stays in place.
        val cause = RuntimeException("Twilio error 21608")
        val outer = RuntimeException("auth call failed", cause)
        val mapped = mapTwilioTrialError(outer)
        assertNotSame(outer, mapped)
    }

    @Test fun `detection is case-insensitive`() {
        val original = RuntimeException("TWILIO ERROR 21608")
        val mapped = mapTwilioTrialError(original)
        assertNotSame(original, mapped)
    }

    @Test fun `non-trial error is returned unchanged (preserves stack + class)`() {
        val original = IllegalStateException("network unreachable")
        val mapped = mapTwilioTrialError(original)
        // Identity equality — the original throwable is returned so
        // Crashlytics gets the real class + stack. A wrap would lose
        // both.
        assertSame(original, mapped)
    }

    @Test fun `null-message throwable is returned unchanged (no false positive)`() {
        val original = NullPointerException()
        val mapped = mapTwilioTrialError(original)
        assertSame(original, mapped)
    }

    @Test fun `unverified word alone (without twilio) does NOT trigger rewrite`() {
        // "Unverified" appears in many other error paths (KYC, email,
        // etc.). Pin so we don't over-rewrite — the two-word combo is
        // intentional.
        val original = RuntimeException("Account is unverified")
        val mapped = mapTwilioTrialError(original)
        assertSame(original, mapped)
    }

    @Test fun `mapped exception preserves the original as cause`() {
        // Even though the message changes, the cause chain must
        // include the original so logs can still trace the failure.
        val original = RuntimeException("Twilio 21608 trial mode")
        val mapped = mapTwilioTrialError(original)
        assertSame(original, mapped.cause)
    }
}
