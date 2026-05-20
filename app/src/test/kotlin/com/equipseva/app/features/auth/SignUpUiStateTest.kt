package com.equipseva.app.features.auth

import com.equipseva.app.features.auth.state.FormUiState
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the 4-condition canSubmit gate that drives the Sign-up CTA. The
 * VM applies the same Validators on submit too, but the gate is what
 * enables the button — if any one of the four conditions silently drops,
 * the user either taps a disabled button forever (sign-ups stall) or
 * fires a request that fails server-side with a confusing error.
 */
class SignUpUiStateTest {

    private val good = SignUpViewModel.UiState(
        fullName = "Ganesh Dhanavath",
        email = "ganesh@example.com",
        password = "Password1",
        role = UserRole.HOSPITAL,
    )

    @Test fun `happy path is submittable`() {
        assertTrue(good.canSubmit)
    }

    @Test fun `submitting form blocks canSubmit even when fields are valid`() {
        assertFalse(
            good.copy(form = FormUiState(submitting = true)).canSubmit,
        )
    }

    @Test fun `fullName under 2 chars blocks`() {
        assertFalse(good.copy(fullName = "G").canSubmit)
        // Leading/trailing whitespace doesn't pad the length.
        assertFalse(good.copy(fullName = " G ").canSubmit)
        assertTrue(good.copy(fullName = "Go").canSubmit)
    }

    @Test fun `bad email blocks`() {
        assertFalse(good.copy(email = "").canSubmit)
        assertFalse(good.copy(email = "no-at-sign").canSubmit)
        assertFalse(good.copy(email = "user@host").canSubmit) // no TLD
    }

    @Test fun `weak password blocks`() {
        assertFalse(good.copy(password = "").canSubmit)
        assertFalse(good.copy(password = "short1").canSubmit) // < 8
        assertFalse(good.copy(password = "abcdefgh").canSubmit) // no digit
        assertFalse(good.copy(password = "12345678").canSubmit) // no letter
    }

    @Test fun `null role blocks`() {
        // Role-tile picker has to be tapped before submit is allowed.
        assertFalse(good.copy(role = null).canSubmit)
    }

    @Test fun `every recognized role is acceptable on the picker`() {
        // Server-side enum is what blocks bad picks — the form gate just
        // wants any non-null UserRole. Catches a future "v2 admin-only"
        // role accidentally surfacing here.
        UserRole.entries.forEach { role ->
            assertTrue(
                "role=${role.name} should be submittable",
                good.copy(role = role).canSubmit,
            )
        }
    }
}
