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
        val canSubmit: Boolean
            get() = canSubmitSignUp(
                submitting = form.submitting,
                fullName = fullName,
                email = email,
                password = password,
                hasRole = role != null,
            )
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
        // Cap at 100 chars — without this the field happily accepts a
        // pasted 10 KB blob, which then either truncates server-side
        // (silent data corruption) or wedges the form submit. 100 is a
        // generous upper bound for an Indian legal name.
        val capped = value.take(100)
        _state.update { it.copy(fullName = capped, fullNameError = null, form = it.form.copy(errorMessage = null)) }
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

        val errors = validateSignUp(current.fullName, current.email, current.password, current.role)
        if (errors.hasAny) {
            _state.update {
                it.copy(
                    fullNameError = errors.fullNameError,
                    emailError = errors.emailError,
                    passwordError = errors.passwordError,
                    form = if (errors.roleMissing) {
                        it.form.copy(errorMessage = "Pick how you'll use EquipSeva")
                    } else it.form,
                )
            }
            return
        }

        // Validator passed → role is non-null. Capture it for the
        // server-write block below.
        val role = checkNotNull(current.role)
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
                            // Tell the user to check their inbox. Reset the
                            // whole UiState (fullName, email, password, role)
                            // so a follow-up tap on Create account doesn't
                            // re-submit the same email and hit
                            // "Email already registered" before they've had
                            // a chance to click the verification link.
                            _state.update { UiState() }
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

/**
 * Inline-validation errors for the sign-up form. `roleMissing`
 * surfaces separately because role is communicated via a form-level
 * banner, not an inline field error.
 */
internal data class SignUpErrors(
    val fullNameError: String?,
    val emailError: String?,
    val passwordError: String?,
    val roleMissing: Boolean,
) {
    val hasAny: Boolean
        get() = fullNameError != null || emailError != null ||
            passwordError != null || roleMissing
}

/**
 * Pure form-validation for the sign-up screen. Extracted so the gate
 * can be exercised without the VM scaffolding (AuthRepository, Hilt,
 * crash reporter, etc.).
 */
internal fun validateSignUp(
    fullName: String,
    email: String,
    password: String,
    role: UserRole?,
): SignUpErrors {
    val fullNameError = when {
        fullName.trim().length < 2 -> "Enter your full name"
        // Reject names with no actual letters (e.g. "@#$%" or pure
        // emoji). Postgres stores them as-is on `full_name NOT NULL`
        // and they surface as garbage in engineer-directory cards.
        !fullName.any { it.isLetter() } -> "Enter a valid name (letters required)"
        else -> null
    }
    val emailError = if (Validators.emailIsValid(email)) null else "Enter a valid email"
    val passwordError = Validators.passwordWeakness(password)
    return SignUpErrors(
        fullNameError = fullNameError,
        emailError = emailError,
        passwordError = passwordError,
        roleMissing = role == null,
    )
}

/**
 * Submit-button gate on the sign-up form.
 *
 * Enabled when ALL of:
 *   1. NOT submitting
 *   2. fullName (after trim) is at least 2 chars
 *   3. fullName contains at least one letter (rejects emoji-only /
 *      punctuation-only names — postgres stores them and they
 *      surface as garbage in engineer-directory cards)
 *   4. email passes [Validators.emailIsValid]
 *   5. password passes [Validators.passwordIsStrong]
 *   6. role has been picked
 *
 * Pin all six conditions — the letter-check on fullName is a
 * regression target: signup used to accept "@#$%" or pure-emoji
 * names which then leaked into the directory.
 *
 * This gate is the OUTER signup permission — distinct from
 * [validateSignUp] which produces per-field error labels. The outer
 * gate stays silent when the form is incomplete; the validator
 * surfaces errors only after the user types into a field and moves
 * on.
 */
internal fun canSubmitSignUp(
    submitting: Boolean,
    fullName: String,
    email: String,
    password: String,
    hasRole: Boolean,
): Boolean = !submitting &&
    fullName.trim().length >= 2 &&
    fullName.any { it.isLetter() } &&
    Validators.emailIsValid(email) &&
    Validators.passwordIsStrong(password) &&
    hasRole
