package com.equipseva.app.features.auth.state

/**
 * Shared shape every auth form ViewModel uses. Keeps screens visually consistent
 * (button enable/disable rules, error banner placement, loading spinners).
 */
data class FormUiState(
    val submitting: Boolean = false,
    val errorMessage: String? = null,
)

data class EmailPasswordFormState(
    val email: String = "",
    val password: String = "",
    val emailError: String? = null,
    val passwordError: String? = null,
    val form: FormUiState = FormUiState(),
) {
    val canSubmit: Boolean
        get() = canSubmitEmailPasswordForm(form.submitting, email, password)
}

data class EmailOnlyFormState(
    val email: String = "",
    val emailError: String? = null,
    val form: FormUiState = FormUiState(),
) {
    val canSubmit: Boolean
        get() = canSubmitEmailOnlyForm(form.submitting, email)
}

/**
 * Submit-button gate for the email+password auth forms (Sign In,
 * Sign Up password step, Change Password).
 *
 * Enabled when ALL of:
 *   1. NOT submitting (prevents double-tap during in-flight POST)
 *   2. email is non-blank (any character — strict validation happens
 *      in the validateSignIn / validateSignUp helpers; this gate is
 *      just "the user typed something")
 *   3. password is non-blank
 *
 * Pin the isNotBlank (not isNotEmpty) — whitespace-only input
 * shouldn't enable submit. The downstream validators trim again, but
 * pin both layers so a refactor that dropped this gate doesn't allow
 * a "   " press through to the server.
 */
internal fun canSubmitEmailPasswordForm(
    submitting: Boolean,
    email: String,
    password: String,
): Boolean = !submitting && email.isNotBlank() && password.isNotBlank()

/**
 * Submit-button gate for the email-only auth form (Forgot Password,
 * Change Email).
 *
 * Sibling of [canSubmitEmailPasswordForm] but without the password
 * check. Pin so a refactor that unified them wouldn't accidentally
 * require a password on the forgot-password screen.
 */
internal fun canSubmitEmailOnlyForm(
    submitting: Boolean,
    email: String,
): Boolean = !submitting && email.isNotBlank()

