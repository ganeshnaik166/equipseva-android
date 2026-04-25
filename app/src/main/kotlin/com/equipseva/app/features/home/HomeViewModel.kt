package com.equipseva.app.features.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.prefs.UserPrefs
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.features.auth.UserRole
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class HomeViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
    private val userPrefs: UserPrefs,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val greetingName: String = "there",
        val role: UserRole? = null,
        val errorMessage: String? = null,
    )

    sealed interface Effect {
        data class ShowMessage(val text: String) : Effect
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private val _effects = Channel<Effect>(Channel.BUFFERED)
    val effects = _effects.receiveAsFlow()

    init {
        // Combine sign-in state with the active-role pref so that flipping the
        // role from the Profile screen re-emits and the dispatcher swaps to the
        // new role's dashboard without needing a navigation event.
        viewModelScope.launch {
            combine(
                authRepository.sessionState
                    .filterIsInstance<AuthSession.SignedIn>(),
                userPrefs.activeRole.distinctUntilChanged(),
            ) { session, activeRoleKey -> session.userId to activeRoleKey }
                .distinctUntilChanged()
                .collect { (userId, activeRoleKey) ->
                    load(userId, activeRoleOverride = activeRoleKey)
                }
        }
    }

    fun onRetry() {
        viewModelScope.launch {
            val current = authRepository.sessionState.first()
            if (current is AuthSession.SignedIn) {
                val activeRole = userPrefs.activeRole.first()
                load(current.userId, activeRoleOverride = activeRole)
            }
        }
    }

    /**
     * Pulls the canonical Profile row (for greeting name + canonical role) and
     * prefers the locally-cached `activeRole` when it's set. The cache is
     * written by the Profile role-editor on a successful update, so the
     * dispatcher swaps before the next round-trip.
     */
    private suspend fun load(userId: String, activeRoleOverride: String?) {
        _state.update { it.copy(loading = true, errorMessage = null) }
        profileRepository.fetchById(userId)
            .onSuccess { profile ->
                val cachedRole = activeRoleOverride
                    ?.takeIf { it.isNotBlank() }
                    ?.let { UserRole.fromKey(it) }
                _state.update {
                    it.copy(
                        loading = false,
                        greetingName = profile?.displayName ?: "there",
                        role = cachedRole ?: profile?.role,
                        errorMessage = null,
                    )
                }
            }
            .onFailure { error ->
                val msg = error.toUserMessage()
                _state.update {
                    it.copy(
                        loading = false,
                        errorMessage = msg,
                    )
                }
                _effects.send(Effect.ShowMessage(msg))
            }
    }
}
