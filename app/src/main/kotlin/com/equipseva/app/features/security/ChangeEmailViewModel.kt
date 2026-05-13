package com.equipseva.app.features.security

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.Validators
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class ChangeEmailViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
) : ViewModel() {

    data class UiState(
        val currentPassword: String = "",
        val newEmail: String = "",
        val submitting: Boolean = false,
        val passwordError: String? = null,
        val emailError: String? = null,
        val errorMessage: String? = null,
    )

    sealed interface Effect {
        data class Success(val message: String) : Effect
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    // SharedFlow(replay = 0) — see ChangePasswordViewModel + PR #584.
    private val _effects = kotlinx.coroutines.flow.MutableSharedFlow<Effect>(
        extraBufferCapacity = 4,
    )
    val effects: kotlinx.coroutines.flow.Flow<Effect> = _effects

    fun onPasswordChange(value: String) {
        _state.update {
            it.copy(
                currentPassword = value,
                passwordError = null,
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

    /**
     * Updates `profiles.email` (the contact email shown to hospitals on
     * the engineer's public profile and used for KYC contact). The
     * auth.users.email — i.e. the sign-in identity — stays as-is.
     *
     * Re-auth gate: requires the current password before the update
     * lands. Without it, a thief with an unlocked phone could quietly
     * redirect KYC + payment-notification email to themselves.
     */
    fun onSubmit() {
        val current = _state.value
        if (current.submitting) return

        val password = current.currentPassword
        val trimmed = current.newEmail.trim()
        val passwordError = if (password.isBlank()) "Enter your current password" else null
        val emailError = when {
            trimmed.isBlank() -> "Enter your new email"
            !Validators.emailIsValid(trimmed) -> "Enter a valid email address"
            else -> null
        }
        if (passwordError != null || emailError != null) {
            _state.update { it.copy(passwordError = passwordError, emailError = emailError) }
            return
        }

        _state.update { it.copy(submitting = true, errorMessage = null) }
        viewModelScope.launch {
            val userId = authRepository.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .firstOrNull()
                ?.userId
            if (userId.isNullOrBlank()) {
                _state.update {
                    it.copy(submitting = false, errorMessage = "Sign in again to change your email.")
                }
                return@launch
            }
            val reauth = authRepository.verifyCurrentPassword(password)
            if (reauth.isFailure) {
                _state.update {
                    it.copy(
                        submitting = false,
                        passwordError = "Current password is incorrect.",
                    )
                }
                return@launch
            }
            profileRepository.updateBasicInfo(userId = userId, email = trimmed).fold(
                onSuccess = {
                    _state.update { UiState() }
                    _effects.emit(Effect.Success("Email updated"))
                },
                onFailure = { ex ->
                    _state.update {
                        it.copy(submitting = false, errorMessage = ex.toUserMessage())
                    }
                },
            )
        }
    }
}
