package com.equipseva.app.features.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.toAuthError
import com.equipseva.app.core.util.Validators
import com.equipseva.app.features.auth.state.AuthEffect
import com.equipseva.app.features.auth.state.EmailOnlyFormState
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

    private val _state = MutableStateFlow(EmailOnlyFormState())
    val state: StateFlow<EmailOnlyFormState> = _state.asStateFlow()

    private val _effects = Channel<AuthEffect>(Channel.BUFFERED)
    val effects = _effects.receiveAsFlow()

    fun onEmailChange(value: String) {
        _state.update { it.copy(email = value, emailError = null, form = it.form.copy(errorMessage = null)) }
    }

    fun onSubmit() {
        val current = _state.value
        if (current.form.submitting) return

        if (!Validators.emailIsValid(current.email)) {
            _state.update { it.copy(emailError = "Enter a valid email") }
            return
        }

        _state.update { it.copy(form = FormUiState(submitting = true)) }
        viewModelScope.launch {
            authRepository.sendEmailOtp(current.email.trim()).fold(
                onSuccess = {
                    _state.update { it.copy(form = FormUiState()) }
                    _effects.send(AuthEffect.NavigateToOtpVerify(current.email.trim()))
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
