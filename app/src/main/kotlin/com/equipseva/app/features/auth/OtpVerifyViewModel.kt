package com.equipseva.app.features.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.toAuthError
import com.equipseva.app.core.util.Validators
import com.equipseva.app.features.auth.state.AuthEffect
import com.equipseva.app.features.auth.state.FormUiState
import com.equipseva.app.features.auth.state.OtpFormState
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

private const val RESEND_COOLDOWN_SECONDS = 30

@HiltViewModel
class OtpVerifyViewModel @Inject constructor(
    private val authRepository: AuthRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(OtpFormState(email = ""))
    val state: StateFlow<OtpFormState> = _state.asStateFlow()

    private val _effects = Channel<AuthEffect>(Channel.BUFFERED)
    val effects = _effects.receiveAsFlow()

    fun setEmail(email: String) {
        if (_state.value.email == email) return
        _state.value = OtpFormState(email = email)
        startResendCooldown()
    }

    fun onCodeChange(value: String) {
        _state.update { it.copy(code = value, codeError = null, form = it.form.copy(errorMessage = null)) }
    }

    fun onSubmit() {
        val current = _state.value
        if (current.form.submitting) return
        if (!Validators.otpIsSixDigit(current.code)) {
            _state.update { it.copy(codeError = "Enter the 6-digit code") }
            return
        }
        _state.update { it.copy(form = FormUiState(submitting = true)) }
        viewModelScope.launch {
            authRepository.verifyEmailOtp(current.email, current.code).fold(
                onSuccess = {
                    _state.update { it.copy(form = FormUiState()) }
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

    fun onResend() {
        val current = _state.value
        if (!current.canResend) return
        _state.update { it.copy(form = FormUiState(submitting = true)) }
        viewModelScope.launch {
            authRepository.sendEmailOtp(current.email).fold(
                onSuccess = {
                    _state.update { it.copy(form = FormUiState()) }
                    _effects.send(AuthEffect.ShowMessage("New code sent to ${current.email}"))
                    startResendCooldown()
                },
                onFailure = { ex ->
                    _state.update {
                        it.copy(form = FormUiState(errorMessage = ex.toAuthError().userMessage))
                    }
                },
            )
        }
    }

    private fun startResendCooldown() {
        viewModelScope.launch {
            for (remaining in RESEND_COOLDOWN_SECONDS downTo 0) {
                _state.update { it.copy(resendSecondsRemaining = remaining) }
                if (remaining == 0) break
                delay(1_000)
            }
        }
    }
}
