package com.equipseva.app.features.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.prefs.UserPrefs
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.push.DeviceTokenRegistrar
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChangedBy
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * Top-level session state used by the root nav graph to gate AUTH vs MAIN.
 *
 * Source-of-truth ordering for role:
 *  1. `profiles.role_confirmed = true` on the server (synced into local prefs on sign-in).
 *  2. Local pref written during a confirmed RoleSelect on this device.
 *
 * If neither holds, the user lands on RoleSelect.
 */
@HiltViewModel
class SessionViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
    private val userPrefs: UserPrefs,
    private val deviceTokenRegistrar: DeviceTokenRegistrar,
) : ViewModel() {

    private val bootstrapping = MutableStateFlow(false)

    /** One-shot toasts surfaced by the sign-in gate (e.g. "Account deleted"). */
    private val _messages = Channel<String>(Channel.BUFFERED)
    val messages = _messages.receiveAsFlow()

    init {
        viewModelScope.launch {
            authRepository.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .distinctUntilChangedBy { it.userId }
                .collect { signedIn ->
                    // Re-register FCM token under the new user id. onNewToken
                    // only fires on actual token rotation, so a returning
                    // user signing in on a device whose previous session
                    // was revoke()'d would otherwise have no row in
                    // device_tokens and receive zero pushes. Best-effort.
                    runCatching { deviceTokenRegistrar.refresh() }
                    bootstrapProfile(signedIn.userId)
                }
        }
        viewModelScope.launch {
            authRepository.sessionState.collect { session ->
                if (session is AuthSession.SignedOut) {
                    userPrefs.clearActiveRole()
                    bootstrapping.value = false
                }
            }
        }
    }

    val tourSeen: StateFlow<Boolean> = userPrefs.observeTourSeen().stateIn(
        scope = viewModelScope,
        // Eagerly so the upstream stays alive across app background → foreground.
        // WhileSubscribed(5_000) caused the StateFlow to cold-restart at the
        // initialValue after >5s in background, which triggered AppNavGraph's
        // Loading branch and unmounted the entire NavHost on every resume.
        started = SharingStarted.Eagerly,
        initialValue = true, // assume seen until first emission so we don't flash the tour on splash
    )

    val state: StateFlow<SessionState> =
        combine(
            authRepository.sessionState,
            userPrefs.activeRole,
            bootstrapping,
        ) { session, role, syncing ->
            when (session) {
                is AuthSession.Unknown -> SessionState.Loading
                is AuthSession.SignedOut -> SessionState.SignedOut
                is AuthSession.SignedIn -> when {
                    !role.isNullOrBlank() -> SessionState.Ready(session.userId, session.email, role)
                    syncing -> SessionState.Loading
                    else -> SessionState.NeedsRole(session.userId, session.email)
                }
            }
        }.stateIn(
            scope = viewModelScope,
            // Eagerly: the upstream session subscription must survive
            // background → foreground transitions. With WhileSubscribed(5_000)
            // the StateFlow cold-restarted at `Loading` on every resume after
            // 5s+, which mounted SplashScreen() in AppNavGraph and tore down
            // the entire NavHost — wiping in-flight forms and the back stack.
            started = SharingStarted.Eagerly,
            initialValue = SessionState.Loading,
        )

    private suspend fun bootstrapProfile(userId: String) {
        // Always fetch the profile, even when a role is cached locally. The
        // previous fast-path skip caused a "zombie session" — when an admin
        // hard-deleted a user server-side, the cached role kept the app on
        // Home with stale data forever instead of bouncing to Welcome.
        val cached = userPrefs.activeRole.first()
        bootstrapping.value = cached.isNullOrBlank()
        try {
            val result = profileRepository.fetchById(userId)
            val fetched = result.getOrNull()
            // Server-deleted account: row is gone (success(null)) while
            // Supabase still hands us a session token. Sign out + tell the
            // user. Distinct from network failure (Result.failure) where we
            // keep the cached session.
            if (result.isSuccess && fetched == null) {
                _messages.trySend("Your account is no longer active. Sign in again.")
                runCatching { userPrefs.clearActiveRole() }
                runCatching { authRepository.signOut() }
                return
            }
            // Defense-in-depth gate: legacy soft-delete (is_active=false)
            // ships us a row but flags it inactive. Hard delete normally
            // removes the row entirely (handled above).
            if (fetched != null && !fetched.isActive) {
                _messages.trySend("This account was deleted. Contact support to restore it.")
                runCatching { userPrefs.clearActiveRole() }
                runCatching { authRepository.signOut() }
                return
            }
            // Only update the cached role when the server confirms it; we
            // don't want a transient empty fetch to wipe a previously-set
            // active role.
            val confirmedRole = fetched?.takeIf { it.roleConfirmed }?.rawRoleKey
            if (!confirmedRole.isNullOrBlank() && cached.isNullOrBlank()) {
                userPrefs.setActiveRole(confirmedRole)
            }
        } finally {
            bootstrapping.value = false
        }
    }
}

sealed interface SessionState {
    data object Loading : SessionState
    data object SignedOut : SessionState
    data class NeedsRole(val userId: String, val email: String?) : SessionState
    data class Ready(val userId: String, val email: String?, val role: String) : SessionState
}
