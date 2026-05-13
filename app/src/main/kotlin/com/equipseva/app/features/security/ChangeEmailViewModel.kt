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
        val newEmail: String = "",
        val submitting: Boolean = false,
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
     * Direct update to `profiles.email` only — no Supabase auth confirmation
     * link, no current-password re-auth. The auth.users.email (sign-in
     * identity) stays as-is; this changes only the contact email shown to
     * hospitals on the engineer's public profile and used for KYC contact.
     */
    fun onSubmit() {
        val current = _state.value
        if (current.submitting) return

        val trimmed = current.newEmail.trim()
        val emailError = when {
            trimmed.isBlank() -> "Enter your new email"
            !Validators.emailIsValid(trimmed) -> "Enter a valid email address"
            else -> null
        }
        if (emailError != null) {
            _state.update { it.copy(emailError = emailError) }
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
