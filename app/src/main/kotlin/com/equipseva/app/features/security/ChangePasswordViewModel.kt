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

        val currentError = if (currentPwd.isBlank()) "Enter your current password" else null
        // Mirror the SignUp policy via shared Validators.passwordWeakness so
        // a user can't set a password on this screen that signup would have
        // rejected. Earlier code only checked length, letting through
        // "aaaaaaaa" / "12345678".
        val newError = when {
            newPwd.isBlank() -> "Enter a new password"
            newPwd == currentPwd -> "Choose a password different from your current one"
            else -> com.equipseva.app.core.util.Validators.passwordWeakness(newPwd)
        }
        val confirmError = when {
            confirmPwd.isBlank() -> "Re-enter your new password"
            confirmPwd != newPwd -> "Passwords don't match"
            else -> null
        }

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
