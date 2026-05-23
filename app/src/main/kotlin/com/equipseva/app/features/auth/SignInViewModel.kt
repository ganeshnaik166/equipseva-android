package com.equipseva.app.features.auth

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.toAuthError
import com.equipseva.app.core.util.Validators
import com.equipseva.app.features.auth.google.GoogleSignInClient
import com.equipseva.app.features.auth.google.GoogleSignInResult
import com.equipseva.app.features.auth.state.AuthEffect
import com.equipseva.app.features.auth.state.EmailPasswordFormState
import com.equipseva.app.features.auth.state.FormUiState
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class SignInViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val googleSignInClient: GoogleSignInClient,
) : ViewModel() {

    private val _state = MutableStateFlow(EmailPasswordFormState())
    val state: StateFlow<EmailPasswordFormState> = _state.asStateFlow()

    // SharedFlow(replay = 0) per PR #584 — buffered Channel would
    // refire NavigateToHome if the screen was popped after the emit
    // but before the collector consumed it.
    private val _effects = kotlinx.coroutines.flow.MutableSharedFlow<AuthEffect>(
        extraBufferCapacity = 4,
    )
    val effects: kotlinx.coroutines.flow.Flow<AuthEffect> = _effects

    fun onEmailChange(value: String) {
        // RFC 5321 caps the local-part at 64 and the domain at 255; the
        // total practical max is around 254. Cap at 255 to swallow paste
        // abuse while still admitting every real address.
        _state.update {
            it.copy(email = value.take(255), emailError = null, form = it.form.copy(errorMessage = null))
        }
    }

    fun onPasswordChange(value: String) {
        // Reasonable upper bound — Supabase auth itself caps password
        // length, but capping client-side keeps a giant paste from
        // wedging Compose recomposition before the submit-time check.
        _state.update {
            it.copy(password = value.take(128), passwordError = null, form = it.form.copy(errorMessage = null))
        }
    }

    fun onSubmit() {
        val current = _state.value
        if (current.form.submitting) return

        val errors = validateSignIn(current.email, current.password)
        if (errors.hasAny) {
            _state.update {
                it.copy(emailError = errors.emailError, passwordError = errors.passwordError)
            }
            return
        }

        _state.update { it.copy(form = FormUiState(submitting = true)) }
        viewModelScope.launch {
            authRepository.signInWithEmailPassword(current.email.trim(), current.password).fold(
                onSuccess = {
                    _state.update { it.copy(form = FormUiState()) }
                    _effects.emit(AuthEffect.NavigateToHome)
                },
                onFailure = { ex ->
                    _state.update {
                        it.copy(form = FormUiState(errorMessage = ex.toAuthError().userMessage))
                    }
                },
            )
        }
    }

    /**
     * Continue-with-Google handler. The SignIn screen previously routed the
     * Google button to onSubmit, which tried to sign in with whatever was
     * typed in email/password (i.e. usually nothing) so the button was
     * effectively a dead UI element.
     */
    fun onGoogleClicked(activityContext: Context) {
        if (_state.value.form.submitting) return
        _state.update { it.copy(form = FormUiState(submitting = true)) }
        viewModelScope.launch {
            when (val result = googleSignInClient.signIn(activityContext)) {
                is GoogleSignInResult.Token -> {
                    authRepository.signInWithGoogleIdToken(result.idToken, result.rawNonce).fold(
                        onSuccess = {
                            _state.update { it.copy(form = FormUiState()) }
                            _effects.emit(AuthEffect.NavigateToHome)
                        },
                        onFailure = { ex ->
                            _state.update {
                                it.copy(form = FormUiState(errorMessage = ex.toAuthError().userMessage))
                            }
                        },
                    )
                }
                is GoogleSignInResult.Cancelled -> {
                    _state.update { it.copy(form = FormUiState()) }
                }
                is GoogleSignInResult.NotConfigured -> {
                    _state.update {
                        it.copy(form = FormUiState(errorMessage = "Google sign-in isn't configured for this build."))
                    }
                }
                is GoogleSignInResult.Error -> {
                    _state.update {
                        it.copy(form = FormUiState(errorMessage = result.message))
                    }
                }
            }
        }
    }

}

/**
 * Inline-validation errors for the sign-in form. `hasAny` is the
 * "block submit" gate; the two fields are surfaced separately as
 * field-level error copy.
 */
internal data class SignInErrors(
    val emailError: String?,
    val passwordError: String?,
) {
    val hasAny: Boolean get() = emailError != null || passwordError != null
}

/**
 * Pure form-validation for the sign-in screen. Extracted so the gate
 * can be exercised without the VM's authRepository / GoogleSignInClient
 * scaffolding.
 */
internal fun validateSignIn(email: String, password: String): SignInErrors =
    SignInErrors(
        emailError = if (Validators.emailIsValid(email)) null else "Enter a valid email",
        passwordError = if (password.isNotBlank()) null else "Password is required",
    )
