package com.equipseva.app.features.auth

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CanSubmitSignUpTest {

    @Test fun `all conditions met returns true`() {
        assertTrue(
            canSubmitSignUp(
                submitting = false,
                fullName = "Asha Rao",
                email = "asha@example.com",
                password = "Secret123",
                hasRole = true,
            ),
        )
    }

    @Test fun `submitting blocks`() {
        assertFalse(
            canSubmitSignUp(true, "Asha Rao", "asha@x.com", "Secret123", true),
        )
    }

    @Test fun `single-char name blocks (under 2-char min)`() {
        assertFalse(
            canSubmitSignUp(false, "A", "asha@x.com", "Secret123", true),
        )
    }

    @Test fun `whitespace-padded short name fails (trim-then-len)`() {
        // Pin .trim().length >= 2 — "A   " trims to "A" which fails.
        assertFalse(
            canSubmitSignUp(false, "A    ", "asha@x.com", "Secret123", true),
        )
    }

    @Test fun `pure-punctuation name blocks (no letters)`() {
        // Critical regression target — signup used to accept "@#$%"
        // which then leaked into the directory.
        assertFalse(
            canSubmitSignUp(false, "@#\$%", "asha@x.com", "Secret123", true),
        )
    }

    @Test fun `pure-emoji name blocks (no letters)`() {
        // Same regression target with emoji input.
        assertFalse(
            canSubmitSignUp(false, "🎉🚀", "asha@x.com", "Secret123", true),
        )
    }

    @Test fun `letter mixed with punctuation passes`() {
        // At least ONE letter is enough.
        assertTrue(
            canSubmitSignUp(false, "Dr. K", "asha@x.com", "Secret123", true),
        )
    }

    @Test fun `invalid email blocks`() {
        assertFalse(
            canSubmitSignUp(false, "Asha Rao", "not-an-email", "Secret123", true),
        )
    }

    @Test fun `weak password blocks`() {
        // Validators.passwordIsStrong gates on length + complexity.
        assertFalse(
            canSubmitSignUp(false, "Asha Rao", "asha@x.com", "abc", true),
        )
    }

    @Test fun `no role picked blocks`() {
        assertFalse(
            canSubmitSignUp(false, "Asha Rao", "asha@x.com", "Secret123", false),
        )
    }
}
