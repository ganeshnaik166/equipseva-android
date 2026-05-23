package com.equipseva.app.features.security

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.InvalidCurrentPasswordException
import com.equipseva.app.core.network.toUserMessage
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
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

    // SharedFlow(replay = 0) drops events with no active collector
    // — matches PR #584's SignUp + Session pattern, prevents a
    // Success effect from phantom-firing on the next ChangePassword
    // visit if the screen was popped mid-RPC.
    private val _effects = kotlinx.coroutines.flow.MutableSharedFlow<Effect>(
        extraBufferCapacity = 4,
    )
    val effects: kotlinx.coroutines.flow.Flow<Effect> = _effects

    // Round 414 — cap password inputs at 128 chars. Longer values are
    // pathological (real users can't type one) and an unbounded paste
    // would wedge compose recomposition while ballooning the auth POST
    // body. Same cap applied to ChangeEmailViewModel.onPasswordChange.
    private fun String.cappedPassword(): String = take(128)

    fun onCurrentPasswordChange(value: String) {
        _state.update {
            it.copy(
                currentPassword = value.cappedPassword(),
                currentPasswordError = null,
                errorMessage = null,
            )
        }
    }

    fun onNewPasswordChange(value: String) {
        _state.update {
            it.copy(
                newPassword = value.cappedPassword(),
                newPasswordError = null,
                errorMessage = null,
            )
        }
    }

    fun onConfirmPasswordChange(value: String) {
        _state.update {
            it.copy(
                confirmPassword = value.cappedPassword(),
                confirmPasswordError = null,
                errorMessage = null,
            )
        }
    }

    fun onSubmit() {
        val current = _state.value
        if (current.submitting) return

        val errors = validateChangePassword(
            currentPassword = current.currentPassword,
            newPassword = current.newPassword,
            confirmPassword = current.confirmPassword,
        )
        val currentError = errors.currentPasswordError
        val newError = errors.newPasswordError
        val confirmError = errors.confirmPasswordError

        if (errors.hasAny) {
            _state.update {
                it.copy(
                    currentPasswordError = currentError,
                    newPasswordError = newError,
                    confirmPasswordError = confirmError,
                )
            }
            return
        }

        val currentPwd = current.currentPassword
        val newPwd = current.newPassword
        _state.update { it.copy(submitting = true, errorMessage = null) }
        viewModelScope.launch {
            authRepository.updatePassword(currentPwd, newPwd).fold(
                onSuccess = {
                    _state.update { UiState() }
                    _effects.emit(Effect.Success("Password updated"))
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

/**
 * Inline-validation errors for the change-password form. The
 * three fields are surfaced separately as field-level error copy.
 */
internal data class ChangePasswordErrors(
    val currentPasswordError: String?,
    val newPasswordError: String?,
    val confirmPasswordError: String?,
) {
    val hasAny: Boolean
        get() = currentPasswordError != null ||
            newPasswordError != null ||
            confirmPasswordError != null
}

/**
 * Pure form-validation for [ChangePasswordViewModel]. Extracted so the
 * gate can be unit-tested without standing up the auth-repository
 * scaffolding. Shared password-strength policy with sign-up (via
 * [com.equipseva.app.core.util.Validators.passwordWeakness]) so a user
 * can't set a password here that signup would have rejected.
 */
internal fun validateChangePassword(
    currentPassword: String,
    newPassword: String,
    confirmPassword: String,
): ChangePasswordErrors {
    val currentError = if (currentPassword.isBlank()) "Enter your current password" else null
    val newError = when {
        newPassword.isBlank() -> "Enter a new password"
        newPassword == currentPassword -> "Choose a password different from your current one"
        else -> com.equipseva.app.core.util.Validators.passwordWeakness(newPassword)
    }
    val confirmError = when {
        confirmPassword.isBlank() -> "Re-enter your new password"
        confirmPassword != newPassword -> "Passwords don't match"
        else -> null
    }
    return ChangePasswordErrors(
        currentPasswordError = currentError,
        newPasswordError = newError,
        confirmPasswordError = confirmError,
    )
}
