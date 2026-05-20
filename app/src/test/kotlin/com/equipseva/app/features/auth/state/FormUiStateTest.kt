package com.equipseva.app.features.auth.state

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the shared "can submit" gates used across the auth + KYC OTP
 * screens. Every login / forgot-password / OTP form reads these derived
 * properties to enable its primary CTA — a regression here either locks
 * the user out of submitting OR enables a submit with empty inputs.
 */
class FormUiStateTest {

    @Test fun `EmailPassword canSubmit requires both fields and not submitting`() {
        assertTrue(
            EmailPasswordFormState(email = "x@y.com", password = "Password1").canSubmit,
        )
        assertFalse(
            EmailPasswordFormState(email = "", password = "Password1").canSubmit,
        )
        assertFalse(
            EmailPasswordFormState(email = "x@y.com", password = "").canSubmit,
        )
        assertFalse(
            EmailPasswordFormState(
                email = "x@y.com",
                password = "Password1",
                form = FormUiState(submitting = true),
            ).canSubmit,
        )
    }

    @Test fun `EmailPassword canSubmit does not validate shape — that's the VM's job`() {
        // Deliberately permissive: the form-level gate only checks non-blank,
        // and the VM applies Validators.emailIsValid / passwordIsStrong on
        // submit. Pin this so we don't accidentally bolt validation onto
        // both layers (which causes the "button stays disabled after a
        // blank+typo correction" UX bug).
        assertTrue(
            EmailPasswordFormState(email = "not-an-email", password = "x").canSubmit,
        )
    }

    @Test fun `EmailOnly canSubmit requires the email field`() {
        assertTrue(EmailOnlyFormState(email = "x@y.com").canSubmit)
        assertFalse(EmailOnlyFormState(email = "").canSubmit)
        assertFalse(
            EmailOnlyFormState(
                email = "x@y.com",
                form = FormUiState(submitting = true),
            ).canSubmit,
        )
    }

    @Test fun `OTP canSubmit requires 6 to 10 digits and not submitting`() {
        // Phone OTP supabase fires is 6 digits, email OTP can be longer —
        // match the same window Validators.otpIsValid pins (validators test
        // already covers the digits-only rule).
        val good = OtpFormState(email = "x@y.com", code = "123456")
        assertTrue(good.canSubmit)

        assertFalse(OtpFormState(email = "x@y.com", code = "12345").canSubmit)
        assertFalse(OtpFormState(email = "x@y.com", code = "12345678901").canSubmit)
        assertFalse(
            good.copy(form = FormUiState(submitting = true)).canSubmit,
        )
    }

    @Test fun `OTP canResend blocks while a cooldown is ticking or submitting`() {
        val ready = OtpFormState(
            email = "x@y.com",
            code = "",
            resendSecondsRemaining = 0,
        )
        assertTrue(ready.canResend)

        assertFalse(ready.copy(resendSecondsRemaining = 30).canResend)
        assertFalse(ready.copy(form = FormUiState(submitting = true)).canResend)
    }
}
