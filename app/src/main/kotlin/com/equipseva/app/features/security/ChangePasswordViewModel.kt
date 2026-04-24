package com.equipseva.app.features.security

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.network.toUserMessage
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
class ChangePasswordViewModel @Inject constructor(
    private val authRepository: AuthRepository,
) : ViewModel() {

    data class UiState(
        val newPassword: String = "",
        val confirmPassword: String = "",
        val submitting: Boolean = false,
        val newPasswordError: String? = null,
        val confirmPasswordError: String? = null,
        val errorMessage: String? = null,
    )

    sealed interface Effect {
        data class Success(val message: String) : Effect
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private val _effects = Channel<Effect>(Channel.BUFFERED)
    val effects = _effects.receiveAsFlow()

    fun onNewPasswordChange(value: String) {
        _state.update {
            it.copy(
                newPassword = value,
                newPasswordError = null,
                errorMessage = null,
            )
        }
    }

    fun onConfirmPasswordChange(value: String) {
        _state.update {
            it.copy(
                confirmPassword = value,
                confirmPasswordError = null,
                errorMessage = null,
            )
        }
    }

    fun onSubmit() {
        val current = _state.value
        if (current.submitting) return

        val newPwd = current.newPassword
        val confirmPwd = current.confirmPassword

        val newError = when {
            newPwd.isBlank() -> "Enter a new password"
            newPwd.length < MIN_PASSWORD_LENGTH -> "Use at least $MIN_PASSWORD_LENGTH characters"
            else -> null
        }
        val confirmError = when {
            confirmPwd.isBlank() -> "Re-enter your new password"
            confirmPwd != newPwd -> "Passwords don't match"
            else -> null
        }

        if (newError != null || confirmError != null) {
            _state.update {
                it.copy(
                    newPasswordError = newError,
                    confirmPasswordError = confirmError,
                )
            }
            return
        }

        _state.update { it.copy(submitting = true, errorMessage = null) }
        viewModelScope.launch {
            authRepository.updatePassword(newPwd).fold(
                onSuccess = {
                    _state.update { UiState() }
                    _effects.send(Effect.Success("Password updated"))
                },
                onFailure = { ex ->
                    _state.update {
                        it.copy(
                            submitting = false,
                            errorMessage = ex.toUserMessage(),
                        )
                    }
                },
            )
        }
    }

    companion object {
        const val MIN_PASSWORD_LENGTH = 8
    }
}
