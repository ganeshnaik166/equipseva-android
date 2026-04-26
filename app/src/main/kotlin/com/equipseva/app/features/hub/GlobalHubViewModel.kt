package com.equipseva.app.features.hub

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.prefs.UserPrefs
import com.equipseva.app.core.data.profile.Profile
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.features.auth.UserRole
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/** Marketplace tile is hub-only, no underlying role; landing falls through to hospital fallback. */
const val HUB_KEY_MARKETPLACE = "marketplace"

@HiltViewModel
class GlobalHubViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
    private val userPrefs: UserPrefs,
) : ViewModel() {

    data class UiState(
        val signedIn: Boolean = false,
        val isFounder: Boolean = false,
        val ownedRoles: Set<String> = emptySet(),
        val activeRoleKey: String? = null,
        val pendingService: String? = null,
        val acting: Boolean = false,
        val error: String? = null,
    )

    sealed interface Effect {
        data class RequireAuth(val serviceKey: String) : Effect
        data object LandOnMain : Effect
        data class ShowMessage(val text: String) : Effect
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private val _effects = Channel<Effect>(Channel.BUFFERED)
    val effects = _effects.receiveAsFlow()

    init {
        viewModelScope.launch {
            authRepository.sessionState.collect { session ->
                when (session) {
                    is AuthSession.SignedIn -> refreshProfile()
                    is AuthSession.SignedOut -> _state.update {
                        it.copy(signedIn = false, isFounder = false, ownedRoles = emptySet(), activeRoleKey = null)
                    }
                    AuthSession.Unknown -> Unit
                }
            }
        }
    }

    private suspend fun refreshProfile() {
        val session = authRepository.sessionState.first()
        if (session !is AuthSession.SignedIn) return
        profileRepository.fetchById(session.userId)
            .onSuccess { profile -> applyProfile(profile, session) }
    }

    private fun applyProfile(profile: Profile?, session: AuthSession.SignedIn) {
        val ownedFromArray = profile?.rawRoleKeys.orEmpty().toSet()
        // Fallback: if server hasn't been migrated yet, treat scalar `role` as a single owned role.
        val owned = if (ownedFromArray.isNotEmpty()) ownedFromArray
            else listOfNotNull(profile?.rawRoleKey).toSet()
        _state.update {
            it.copy(
                signedIn = true,
                isFounder = profile?.isFounder() == true,
                ownedRoles = owned,
                activeRoleKey = profile?.activeRoleKey ?: profile?.rawRoleKey,
            )
        }
    }

    /** User tapped a service card. Routes the action based on auth + ownership. */
    fun onSelect(serviceKey: String) {
        val current = _state.value
        if (current.acting) return

        // Marketplace browser: no role required. Signed-out → auth; signed-in
        // with no roles → grant hospital_admin; else just land.
        if (serviceKey == HUB_KEY_MARKETPLACE) {
            if (!current.signedIn) {
                ServiceSelection.set(null)
                viewModelScope.launch { _effects.send(Effect.RequireAuth(HUB_KEY_MARKETPLACE)) }
                return
            }
            if (current.ownedRoles.isEmpty()) {
                addRoleAndLand(UserRole.HOSPITAL.storageKey)
            } else {
                viewModelScope.launch { _effects.send(Effect.LandOnMain) }
            }
            return
        }

        if (!current.signedIn) {
            ServiceSelection.set(serviceKey)
            viewModelScope.launch { _effects.send(Effect.RequireAuth(serviceKey)) }
            return
        }

        if (serviceKey in current.ownedRoles) {
            // Owns it — flip active and land.
            setActiveAndLand(serviceKey)
        } else {
            // Owns something else — show confirm sheet.
            _state.update { it.copy(pendingService = serviceKey, error = null) }
        }
    }

    fun confirmAddRole() {
        val role = _state.value.pendingService ?: return
        addRoleAndLand(role)
    }

    fun dismissSheet() {
        _state.update { it.copy(pendingService = null, error = null) }
    }

    private fun setActiveAndLand(roleKey: String) {
        _state.update { it.copy(acting = true, error = null) }
        viewModelScope.launch {
            profileRepository.setActiveRole(roleKey)
                .onSuccess {
                    userPrefs.setActiveRole(roleKey)
                    _state.update { it.copy(acting = false, pendingService = null) }
                    _effects.send(Effect.LandOnMain)
                }
                .onFailure { err ->
                    _state.update { it.copy(acting = false, error = err.message ?: "Couldn't switch service") }
                }
        }
    }

    private fun addRoleAndLand(roleKey: String) {
        _state.update { it.copy(acting = true, error = null) }
        viewModelScope.launch {
            profileRepository.addRole(roleKey)
                .onSuccess {
                    userPrefs.setActiveRole(roleKey)
                    refreshProfile()
                    _state.update { it.copy(acting = false, pendingService = null) }
                    _effects.send(Effect.LandOnMain)
                }
                .onFailure { err ->
                    _state.update { it.copy(acting = false, error = err.message ?: "Couldn't add service") }
                }
        }
    }
}
