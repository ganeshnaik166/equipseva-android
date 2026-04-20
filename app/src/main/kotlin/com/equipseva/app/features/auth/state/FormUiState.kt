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
        get() = !form.submitting && email.isNotBlank() && password.isNotBlank()
}

data class EmailOnlyFormState(
    val email: String = "",
    val emailError: String? = null,
    val form: FormUiState = FormUiState(),
) {
    val canSubmit: Boolean
        get() = !form.submitting && email.isNotBlank()
}

data class OtpFormState(
    val email: String,
    val code: String = "",
    val codeError: String? = null,
    val resendSecondsRemaining: Int = 0,
    val form: FormUiState = FormUiState(),
) {
    val canSubmit: Boolean
        get() = !form.submitting && code.length in 6..10
    val canResend: Boolean
        get() = !form.submitting && resendSecondsRemaining == 0
}
