package com.equipseva.app.features.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.toAuthError
import com.equipseva.app.core.util.Validators
import com.equipseva.app.features.auth.state.AuthEffect
import com.equipseva.app.features.auth.state.FormUiState
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class SignUpViewModel @Inject constructor(
    private val authRepository: AuthRepository,
) : ViewModel() {

    data class UiState(
        val fullName: String = "",
        val email: String = "",
        val password: String = "",
        val fullNameError: String? = null,
        val emailError: String? = null,
        val passwordError: String? = null,
        val form: FormUiState = FormUiState(),
    ) {
        val canSubmit: Boolean get() = !form.submitting &&
            fullName.trim().length >= 2 &&
            Validators.emailIsValid(email) &&
            password.length >= MIN_PASSWORD_LENGTH
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private val _effects = Channel<AuthEffect>(Channel.BUFFERED)
    val effects = _effects.receiveAsFlow()

    fun onFullNameChange(value: String) {
        _state.update { it.copy(fullName = value, fullNameError = null, form = it.form.copy(errorMessage = null)) }
    }

    fun onEmailChange(value: String) {
        _state.update { it.copy(email = value, emailError = null, form = it.form.copy(errorMessage = null)) }
    }

    fun onPasswordChange(value: String) {
        _state.update { it.copy(password = value, passwordError = null, form = it.form.copy(errorMessage = null)) }
    }

    fun onSubmit() {
        val current = _state.value
        if (current.form.submitting) return

        val fullNameError = if (current.fullName.trim().length >= 2) null else "Enter your full name"
        val emailError = if (Validators.emailIsValid(current.email)) null else "Enter a valid email"
        val passwordError = if (current.password.length >= MIN_PASSWORD_LENGTH) null
            else "Use at least $MIN_PASSWORD_LENGTH characters"
        if (fullNameError != null || emailError != null || passwordError != null) {
            _state.update {
                it.copy(
                    fullNameError = fullNameError,
                    emailError = emailError,
                    passwordError = passwordError,
                )
            }
            return
        }

        _state.update { it.copy(form = FormUiState(submitting = true)) }
        viewModelScope.launch {
            val targetEmail = current.email.trim()
            authRepository.signUpWithEmailPassword(
                email = targetEmail,
                password = current.password,
                fullName = current.fullName.trim(),
            ).fold(
                onSuccess = { outcome ->
                    when (outcome) {
                        com.equipseva.app.core.auth.SignUpOutcome.AutoSignedIn -> {
                            _state.update { it.copy(form = FormUiState()) }
                            // Session will transition; AuthHostInline routes to Home.
                            _effects.send(AuthEffect.NavigateToHome)
                        }
                        com.equipseva.app.core.auth.SignUpOutcome.NeedsEmailConfirmation -> {
                            // Supabase "Confirm email" is ON — no session yet.
                            // Tell the user to check their inbox + leave them
                            // on the form so they can read the toast and back
                            // out to Sign in once the link is clicked.
                            _state.update { it.copy(form = FormUiState()) }
                            _effects.send(
                                AuthEffect.ShowMessage(
                                    "Verification link sent to $targetEmail. Open it, then sign in.",
                                ),
                            )
                        }
                    }
                },
                onFailure = { ex ->
                    _state.update {
                        it.copy(form = FormUiState(errorMessage = ex.toAuthError().userMessage))
                    }
                },
            )
        }
    }

    companion object {
        // Mirror Validators.kt's 8-char floor so the UI prompt and the
        // server expectation agree. Old "6+" copy let users submit
        // passwords the backend would refuse.
        const val MIN_PASSWORD_LENGTH = 8
    }
}
