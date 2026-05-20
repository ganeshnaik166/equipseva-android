package com.equipseva.app.features.security

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.InvalidCurrentPasswordException
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
        val currentPassword: String = "",
        val newPassword: String = "",
        val confirmPassword: String = "",
        val submitting: Boolean = false,
        val currentPasswordError: String? = null,
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

    fun onCurrentPasswordChange(value: String) {
        _state.update {
            it.copy(
                currentPassword = value,
                currentPasswordError = null,
                errorMessage = null,
            )
        }
    }

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

        val currentPwd = current.currentPassword
        val newPwd = current.newPassword
        val confirmPwd = current.confirmPassword

        val errors = validateChangePassword(currentPwd, newPwd, confirmPwd)
        val currentError = errors.currentPasswordError
        val newError = errors.newPasswordError
        val confirmError = errors.confirmPasswordError

        if (currentError != null || newError != null || confirmError != null) {
            _state.update {
                it.copy(
                    currentPasswordError = currentError,
                    newPasswordError = newError,
                    confirmPasswordError = confirmError,
                )
            }
            return
        }

        _state.update { it.copy(submitting = true, errorMessage = null) }
        viewModelScope.launch {
            authRepository.updatePassword(currentPwd, newPwd).fold(
                onSuccess = {
                    _state.update { UiState() }
                    _effects.send(Effect.Success("Password updated"))
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

    companion object {
        const val MIN_PASSWORD_LENGTH = 8
    }
}

/**
 * Inline validation result for the change-password form. Each field
 * carries its own error string (or null when clean) so the screen can
 * surface them next to the right input. Pulled out of
 * [ChangePasswordViewModel.onSubmit] so the rules are testable without
 * standing up an AuthRepository.
 */
internal data class ChangePasswordErrors(
    val currentPasswordError: String?,
    val newPasswordError: String?,
    val confirmPasswordError: String?,
)

/**
 * Apply the same rules [ChangePasswordViewModel.onSubmit] runs:
 *  - current password must be non-blank
 *  - new password must be non-blank, ≥ MIN_PASSWORD_LENGTH, AND different
 *    from the current one
 *  - confirm must be non-blank AND equal to the new password
 *
 * Returns a triple of nullable error strings — null means the field is
 * clean.
 */
internal fun validateChangePassword(
    currentPwd: String,
    newPwd: String,
    confirmPwd: String,
): ChangePasswordErrors = ChangePasswordErrors(
    currentPasswordError = if (currentPwd.isBlank()) "Enter your current password" else null,
    newPasswordError = when {
        newPwd.isBlank() -> "Enter a new password"
        newPwd.length < ChangePasswordViewModel.MIN_PASSWORD_LENGTH ->
            "Use at least ${ChangePasswordViewModel.MIN_PASSWORD_LENGTH} characters"
        newPwd == currentPwd -> "Choose a password different from your current one"
        else -> null
    },
    confirmPasswordError = when {
        confirmPwd.isBlank() -> "Re-enter your new password"
        confirmPwd != newPwd -> "Passwords don't match"
        else -> null
    },
)
