package com.equipseva.app.features.auth.state

import com.equipseva.app.features.auth.UserRole
import com.equipseva.app.features.auth.SignUpViewModel
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the form-gate logic on the shared auth state shapes:
 *
 *   * [EmailPasswordFormState.canSubmit] — used by Sign-in & similar
 *     plain-email/password screens. Trivially gates on the form not
 *     being mid-submit and both fields being non-blank.
 *   * [EmailOnlyFormState.canSubmit] — used by Forgot Password.
 *   * [SignUpViewModel.UiState.canSubmit] — far more elaborate, gates
 *     on name length+contains-letter, email validity, password
 *     strength, role chosen.
 *
 * These derived properties drive whether the primary CTA is enabled.
 * A regression that ungated `canSubmit` would let users submit empty
 * forms; a regression that over-gated it would silently disable the
 * happy-path button.
 */
class FormUiStateTest {

    // ---- EmailPasswordFormState ----

    @Test fun `EmailPasswordFormState canSubmit false on empty fields`() {
        assertFalse(EmailPasswordFormState().canSubmit)
        assertFalse(EmailPasswordFormState(email = "ravi@x.in").canSubmit)
        assertFalse(EmailPasswordFormState(password = "secret").canSubmit)
    }

    @Test fun `EmailPasswordFormState canSubmit true on both fields filled`() {
        val s = EmailPasswordFormState(email = "ravi@x.in", password = "Secret123!")
        assertTrue(s.canSubmit)
    }

    @Test fun `EmailPasswordFormState canSubmit false while submitting`() {
        val s = EmailPasswordFormState(
            email = "ravi@x.in",
            password = "Secret123!",
            form = FormUiState(submitting = true),
        )
        assertFalse(s.canSubmit)
    }

    // ---- EmailOnlyFormState ----

    @Test fun `EmailOnlyFormState canSubmit gates on email non-blank and not submitting`() {
        assertFalse(EmailOnlyFormState().canSubmit)
        assertFalse(EmailOnlyFormState(email = "   ").canSubmit)
        assertTrue(EmailOnlyFormState(email = "ravi@x.in").canSubmit)
        assertFalse(
            EmailOnlyFormState(email = "ravi@x.in", form = FormUiState(submitting = true))
                .canSubmit,
        )
    }

    // ---- SignUpViewModel.UiState.canSubmit ----

    private fun signUp(
        fullName: String = "Ravi Kumar",
        email: String = "ravi@x.in",
        password: String = "Secret123!",
        role: UserRole? = UserRole.HOSPITAL,
        submitting: Boolean = false,
    ) = SignUpViewModel.UiState(
        fullName = fullName,
        email = email,
        password = password,
        role = role,
        form = FormUiState(submitting = submitting),
    )

    @Test fun `SignUp canSubmit true on the happy path`() {
        assertTrue(signUp().canSubmit)
    }

    @Test fun `SignUp canSubmit false when name is too short`() {
        assertFalse(signUp(fullName = "R").canSubmit)
    }

    @Test fun `SignUp canSubmit false when name is digits only`() {
        // The any-letter gate is intentional — "12 34" is not a name.
        assertFalse(signUp(fullName = "12 34").canSubmit)
    }

    @Test fun `SignUp canSubmit false when email is invalid`() {
        assertFalse(signUp(email = "not-an-email").canSubmit)
        assertFalse(signUp(email = "   ").canSubmit)
    }

    @Test fun `SignUp canSubmit false when password is too weak`() {
        // Short password fails strength gate.
        assertFalse(signUp(password = "abc").canSubmit)
    }

    @Test fun `SignUp canSubmit false when role is not chosen`() {
        assertFalse(signUp(role = null).canSubmit)
    }

    @Test fun `SignUp canSubmit false while submitting even with valid fields`() {
        assertFalse(signUp(submitting = true).canSubmit)
    }

    @Test fun `SignUp canSubmit name with leading-trailing spaces still passes trim`() {
        // The gate uses `fullName.trim().length` — a name padded with
        // spaces still counts.
        assertTrue(signUp(fullName = "  Ravi  ").canSubmit)
    }
}
