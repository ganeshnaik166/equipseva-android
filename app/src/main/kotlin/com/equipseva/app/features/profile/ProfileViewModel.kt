package com.equipseva.app.features.profile

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.prefs.UserPrefs
import com.equipseva.app.core.data.profile.Profile
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.features.auth.UserRole
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChangedBy
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class ProfileViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
    private val userPrefs: UserPrefs,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val profile: Profile? = null,
        val errorMessage: String? = null,
        val roleEditorOpen: Boolean = false,
        val roleEditorSelected: UserRole? = null,
        val roleUpdating: Boolean = false,
        val signingOut: Boolean = false,
    )

    sealed interface Effect {
        data class ShowMessage(val text: String) : Effect
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private val _effects = Channel<Effect>(Channel.BUFFERED)
    val effects = _effects.receiveAsFlow()

    init {
        viewModelScope.launch {
            authRepository.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .distinctUntilChangedBy { it.userId }
                .collect { load(it.userId, initial = true) }
        }
    }

    fun onRefresh() {
        val session = _state.value.profile?.id ?: return
        viewModelScope.launch {
            _state.update { it.copy(refreshing = true) }
            load(session, initial = false)
        }
    }

    fun onOpenRoleEditor() {
        _state.update {
            it.copy(
                roleEditorOpen = true,
                roleEditorSelected = it.profile?.role,
            )
        }
    }

    fun onDismissRoleEditor() {
        if (_state.value.roleUpdating) return
        _state.update { it.copy(roleEditorOpen = false, roleEditorSelected = null) }
    }

    fun onRoleEditorSelect(role: UserRole) {
        _state.update { it.copy(roleEditorSelected = role) }
    }

    fun onRoleEditorConfirm() {
        val current = _state.value
        val target = current.roleEditorSelected ?: return
        val userId = current.profile?.id ?: return
        if (current.roleUpdating) return
        if (target == current.profile?.role) {
            _state.update { it.copy(roleEditorOpen = false, roleEditorSelected = null) }
            return
        }
        _state.update { it.copy(roleUpdating = true) }
        viewModelScope.launch {
            profileRepository.updateRole(userId, target)
                .onSuccess {
                    userPrefs.setActiveRole(target.storageKey)
                    _state.update {
                        it.copy(
                            profile = it.profile?.copy(role = target, rawRoleKey = target.storageKey, roleConfirmed = true),
                            roleEditorOpen = false,
                            roleEditorSelected = null,
                            roleUpdating = false,
                        )
                    }
                    _effects.send(Effect.ShowMessage("Role updated to ${target.displayName}"))
                }
                .onFailure { error ->
                    _state.update { it.copy(roleUpdating = false) }
                    _effects.send(Effect.ShowMessage(error.toUserMessage()))
                }
        }
    }

    fun onSignOut() {
        if (_state.value.signingOut) return
        _state.update { it.copy(signingOut = true) }
        viewModelScope.launch {
            authRepository.signOut()
                .onFailure { error ->
                    _state.update { it.copy(signingOut = false) }
                    _effects.send(Effect.ShowMessage(error.toUserMessage()))
                }
            // On success, SessionViewModel transitions to SignedOut and root nav unmounts this screen.
        }
    }

    private suspend fun load(userId: String, initial: Boolean) {
        if (initial) _state.update { it.copy(loading = true, errorMessage = null) }
        profileRepository.fetchById(userId)
            .onSuccess { profile ->
                _state.update {
                    it.copy(
                        loading = false,
                        refreshing = false,
                        profile = profile,
                        errorMessage = if (profile == null) "Profile not found" else null,
                    )
                }
            }
            .onFailure { error ->
                _state.update {
                    it.copy(
                        loading = false,
                        refreshing = false,
                        errorMessage = error.toUserMessage(),
                    )
                }
            }
    }

}
