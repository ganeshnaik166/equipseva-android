package com.equipseva.app.features.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.toAuthError
import com.equipseva.app.core.data.prefs.UserPrefs
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.util.Validators
import com.equipseva.app.features.auth.state.AuthEffect
import com.equipseva.app.features.auth.state.FormUiState
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class SignUpViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
    private val userPrefs: UserPrefs,
    private val crashReporter: com.equipseva.app.core.observability.CrashReporter,
) : ViewModel() {

    data class UiState(
        val fullName: String = "",
        val email: String = "",
        val password: String = "",
        val role: UserRole? = null,
        val fullNameError: String? = null,
        val emailError: String? = null,
        val passwordError: String? = null,
        val form: FormUiState = FormUiState(),
    ) {
        val canSubmit: Boolean get() = !form.submitting &&
            fullName.trim().length >= 2 &&
            Validators.emailIsValid(email) &&
            Validators.passwordIsStrong(password) &&
            role != null
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    // SharedFlow(replay = 0) for one-shot effects — Channel(BUFFERED)
    // retained NavigateToHome / ShowMessage events across composition
    // teardowns. A user who signed up, signed out, then re-opened the
    // SignUp screen would see the buffered NavigateToHome refire on
    // mount, routing them to Home while signed out.
    private val _effects = kotlinx.coroutines.flow.MutableSharedFlow<AuthEffect>(
        extraBufferCapacity = 4,
    )
    val effects: kotlinx.coroutines.flow.Flow<AuthEffect> = _effects

    fun onFullNameChange(value: String) {
        _state.update { it.copy(fullName = value, fullNameError = null, form = it.form.copy(errorMessage = null)) }
    }

    fun onEmailChange(value: String) {
        _state.update { it.copy(email = value, emailError = null, form = it.form.copy(errorMessage = null)) }
    }

    fun onPasswordChange(value: String) {
        _state.update { it.copy(password = value, passwordError = null, form = it.form.copy(errorMessage = null)) }
    }

    fun onRoleChange(value: UserRole) {
        _state.update { it.copy(role = value, form = it.form.copy(errorMessage = null)) }
    }

    fun onSubmit() {
        val current = _state.value
        if (current.form.submitting) return

        val fullNameError = if (current.fullName.trim().length >= 2) null else "Enter your full name"
        val emailError = if (Validators.emailIsValid(current.email)) null else "Enter a valid email"
        val passwordError = Validators.passwordWeakness(current.password)
        val role = current.role
        if (fullNameError != null || emailError != null || passwordError != null || role == null) {
            _state.update {
                it.copy(
                    fullNameError = fullNameError,
                    emailError = emailError,
                    passwordError = passwordError,
                    form = if (role == null) it.form.copy(errorMessage = "Pick how you'll use EquipSeva") else it.form,
                )
            }
            return
        }

        _state.update { it.copy(form = FormUiState(submitting = true)) }
        viewModelScope.launch {
            val targetEmail = current.email.trim()
            authRepository.signUpWithEmailPassword(
                email = targetEmail,
                password = current.password,
                fullName = current.fullName.trim(),
                role = role,
            ).fold(
                onSuccess = { outcome ->
                    when (outcome) {
                        com.equipseva.app.core.auth.SignUpOutcome.AutoSignedIn -> {
                            // The handle_new_user trigger hardcodes role to
                            // 'engineer' (security fix to block admin escalation
                            // via signup metadata) and `UPDATE` on the role
                            // column is revoked from authenticated. Apply the
                            // selected role through the gated add_role RPC so
                            // active_role + role_confirmed land server-side,
                            // and only mirror the value into UserPrefs after
                            // the server write succeeds — that way a failed
                            // RPC doesn't leave the bottom nav lying about
                            // the role until the next refresh corrects it.
                            profileRepository.addRole(role.storageKey)
                                .onSuccess {
                                    // Mirror to local prefs. If the prefs
                                    // write throws (corrupt SharedPreferences,
                                    // disk full) Crashlytics gets the breadcrumb
                                    // — bottom nav will land on the server's
                                    // active_role on next refresh either way.
                                    runCatching { userPrefs.setActiveRole(role.storageKey) }
                                        .onFailure { crashReporter.report(it, "signup setActiveRole") }
                                }
                                .onFailure { crashReporter.report(it, "signup addRole") }
                            _state.update { it.copy(form = FormUiState()) }
                            // Session will transition; AuthHostInline routes to Home.
                            _effects.emit(AuthEffect.NavigateToHome)
                        }
                        com.equipseva.app.core.auth.SignUpOutcome.NeedsEmailConfirmation -> {
                            // Supabase "Confirm email" is ON — no session yet.
                            // Tell the user to check their inbox + leave them
                            // on the form so they can read the toast and back
                            // out to Sign in once the link is clicked.
                            _state.update { it.copy(form = FormUiState()) }
                            _effects.emit(
                                AuthEffect.ShowMessage(
                                    "Verification link sent to $targetEmail. Open it, then sign in.",
                                ),
                            )
                        }
                    }
                },
                onFailure = { ex ->
                    _state.update {
                        it.copy(form = FormUiState(errorMessage = ex.toAuthError().userMessage))
                    }
                },
            )
        }
    }

}
