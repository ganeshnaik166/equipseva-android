package com.equipseva.app.features.auth.state

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CanSubmitFormTest {

    // ---- canSubmitEmailPasswordForm ----------------------------------

    @Test fun `all conditions met returns true`() {
        assertTrue(
            canSubmitEmailPasswordForm(
                submitting = false,
                email = "user@example.com",
                password = "Secret123",
            ),
        )
    }

    @Test fun `submitting blocks regardless of inputs`() {
        // Prevents double-tap during in-flight POST.
        assertFalse(
            canSubmitEmailPasswordForm(true, "user@example.com", "Secret123"),
        )
    }

    @Test fun `blank email blocks`() {
        assertFalse(canSubmitEmailPasswordForm(false, "", "Secret123"))
        assertFalse(canSubmitEmailPasswordForm(false, "   ", "Secret123"))
    }

    @Test fun `blank password blocks`() {
        assertFalse(canSubmitEmailPasswordForm(false, "user@example.com", ""))
        assertFalse(canSubmitEmailPasswordForm(false, "user@example.com", "   "))
    }

    @Test fun `whitespace-only inputs both block via isNotBlank`() {
        // Critical pin — isNotBlank (not isNotEmpty). A refactor to
        // isNotEmpty would let "   " through which feels broken.
        assertFalse(canSubmitEmailPasswordForm(false, "\t\n", "\t\n"))
    }

    // ---- canSubmitEmailOnlyForm --------------------------------------

    @Test fun `email-only form enables with email only`() {
        assertTrue(
            canSubmitEmailOnlyForm(submitting = false, email = "user@example.com"),
        )
    }

    @Test fun `submitting blocks email-only`() {
        assertFalse(
            canSubmitEmailOnlyForm(true, "user@example.com"),
        )
    }

    @Test fun `blank email blocks email-only`() {
        assertFalse(canSubmitEmailOnlyForm(false, ""))
        assertFalse(canSubmitEmailOnlyForm(false, "   "))
    }

    @Test fun `cross-helper distinction — email-only doesn't require password`() {
        // Pin the asymmetry. A unifying refactor would surface as a
        // mandatory password on the forgot-password / change-email
        // screens (which intentionally don't take one).
        assertTrue(canSubmitEmailOnlyForm(false, "user@x.com"))
        // The same inputs FAIL the password-required gate:
        assertFalse(canSubmitEmailPasswordForm(false, "user@x.com", ""))
    }
}
