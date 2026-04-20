package com.equipseva.app.features.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.Validators
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class ForgotPasswordViewModel @Inject constructor(
    private val authRepository: AuthRepository,
) : ViewModel() {

    data class UiState(
        val email: String = "",
        val submitting: Boolean = false,
        val errorMessage: String? = null,
        val sent: Boolean = false,
        val emailError: String? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    fun onEmailChange(value: String) {
        _state.update { it.copy(email = value, emailError = null, errorMessage = null) }
    }

    fun onSubmit() {
        val current = _state.value
        if (current.submitting) return

        val trimmed = current.email.trim()
        if (!Validators.emailIsValid(trimmed)) {
            _state.update { it.copy(emailError = "Enter a valid email") }
            return
        }

        _state.update { it.copy(submitting = true, errorMessage = null) }
        viewModelScope.launch {
            authRepository.sendPasswordResetEmail(trimmed).fold(
                onSuccess = {
                    _state.update { it.copy(submitting = false, sent = true, errorMessage = null) }
                },
                onFailure = { ex ->
                    _state.update { it.copy(submitting = false, errorMessage = ex.toUserMessage()) }
                },
            )
        }
    }
}
