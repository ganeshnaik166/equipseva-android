package com.equipseva.app.features.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.prefs.UserPrefs
import com.equipseva.app.core.data.profile.ProfileRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChangedBy
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.first
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
) : ViewModel() {

    private val bootstrapping = MutableStateFlow(false)

    init {
        viewModelScope.launch {
            authRepository.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .distinctUntilChangedBy { it.userId }
                .collect { signedIn -> bootstrapProfile(signedIn.userId) }
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
        started = SharingStarted.WhileSubscribed(5_000),
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
            started = SharingStarted.WhileSubscribed(5_000),
            initialValue = SessionState.Loading,
        )

    private suspend fun bootstrapProfile(userId: String) {
        // Fast path: a confirmed role already cached on this device — no need to hit the server.
        if (!userPrefs.activeRole.first().isNullOrBlank()) return
        bootstrapping.value = true
        try {
            profileRepository.fetchById(userId)
                .onSuccess { profile ->
                    val confirmedRole = profile?.takeIf { it.roleConfirmed }?.rawRoleKey
                    if (!confirmedRole.isNullOrBlank()) {
                        userPrefs.setActiveRole(confirmedRole)
                    }
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
