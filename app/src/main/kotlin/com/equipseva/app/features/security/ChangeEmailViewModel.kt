package com.equipseva.app.features.security

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.InvalidCurrentPasswordException
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.Validators
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
class ChangeEmailViewModel @Inject constructor(
    private val authRepository: AuthRepository,
) : ViewModel() {

    data class UiState(
        val currentPassword: String = "",
        val newEmail: String = "",
        val submitting: Boolean = false,
        val currentPasswordError: String? = null,
        val emailError: String? = null,
        val errorMessage: String? = null,
    )

    sealed interface Effect {
        data class Success(val message: String) : Effect
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private val _effects = Channel<Effect>(Channel.BUFFERED)
    val effects = _effects.receiveAsFlow()

    fun onCurrentPasswordChange(value: String) {
        _state.update {
            it.copy(
                currentPassword = value,
                currentPasswordError = null,
                errorMessage = null,
            )
        }
    }

    fun onEmailChange(value: String) {
        _state.update {
            it.copy(
                newEmail = value,
                emailError = null,
                errorMessage = null,
            )
        }
    }

    fun onSubmit() {
        val current = _state.value
        if (current.submitting) return

        val trimmed = current.newEmail.trim()
        val pwd = current.currentPassword
        val pwdError = if (pwd.isBlank()) "Enter your current password" else null
        val emailError = when {
            trimmed.isBlank() -> "Enter your new email"
            !Validators.emailIsValid(trimmed) -> "Enter a valid email address"
            else -> null
        }

        if (pwdError != null || emailError != null) {
            _state.update {
                it.copy(currentPasswordError = pwdError, emailError = emailError)
            }
            return
        }

        _state.update { it.copy(submitting = true, errorMessage = null) }
        viewModelScope.launch {
            authRepository.updateEmail(pwd, trimmed).fold(
                onSuccess = {
                    _state.update { UiState() }
                    _effects.send(Effect.Success("Check your inbox"))
                },
                onFailure = { ex ->
                    if (ex is InvalidCurrentPasswordException) {
                        _state.update {
                            it.copy(
                                submitting = false,
                                currentPasswordError = "Current password is incorrect",
                            )
                        }
                    } else {
                        _state.update {
                            it.copy(
                                submitting = false,
                                errorMessage = ex.toUserMessage(),
                            )
                        }
                    }
                },
            )
        }
    }
}
