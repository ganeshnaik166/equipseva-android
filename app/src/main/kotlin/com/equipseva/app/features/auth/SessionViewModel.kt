package com.equipseva.app.features.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.prefs.UserPrefs
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject

/**
 * Top-level session state used by the root nav graph to gate AUTH vs MAIN.
 */
@HiltViewModel
class SessionViewModel @Inject constructor(
    authRepository: AuthRepository,
    userPrefs: UserPrefs,
) : ViewModel() {

    val state: StateFlow<SessionState> =
        combine(authRepository.sessionState, userPrefs.activeRole) { session, role ->
            when (session) {
                is AuthSession.Unknown -> SessionState.Loading
                is AuthSession.SignedOut -> SessionState.SignedOut
                is AuthSession.SignedIn -> {
                    if (role.isNullOrBlank()) SessionState.NeedsRole(session.userId, session.email)
                    else SessionState.Ready(session.userId, session.email, role)
                }
            }
        }.stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5_000),
            initialValue = SessionState.Loading,
        )
}

sealed interface SessionState {
    data object Loading : SessionState
    data object SignedOut : SessionState
    data class NeedsRole(val userId: String, val email: String?) : SessionState
    data class Ready(val userId: String, val email: String?, val role: String) : SessionState
}
