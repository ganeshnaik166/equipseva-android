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
            password.length >= 6
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
        val passwordError = if (current.password.length >= 6) null else "Password must be 6+ characters"
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
            authRepository.signUpWithEmailPassword(
                email = current.email.trim(),
                password = current.password,
                fullName = current.fullName.trim(),
            ).fold(
                onSuccess = {
                    _state.update { it.copy(form = FormUiState()) }
                    // Supabase config decides whether the new user lands signed-in
                    // immediately (email confirmation off) or has to click a link
                    // first. SessionViewModel observes both states; either way
                    // the host nav graph reacts.
                    _effects.send(AuthEffect.NavigateToHome)
                },
                onFailure = { ex ->
                    _state.update {
                        it.copy(form = FormUiState(errorMessage = ex.toAuthError().userMessage))
                    }
                },
            )
        }
    }
}
