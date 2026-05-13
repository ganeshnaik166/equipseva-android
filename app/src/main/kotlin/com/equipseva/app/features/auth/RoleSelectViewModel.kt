package com.equipseva.app.features.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.prefs.UserPrefs
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.features.auth.state.AuthEffect
import com.equipseva.app.features.auth.state.FormUiState
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class RoleSelectViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
    private val userPrefs: UserPrefs,
) : ViewModel() {

    data class RoleSelectState(
        val roles: List<UserRole> = UserRole.entries,
        val selected: UserRole? = null,
        val form: FormUiState = FormUiState(),
    ) {
        val canConfirm: Boolean get() = selected != null && !form.submitting
    }

    private val _state = MutableStateFlow(RoleSelectState())
    val state: StateFlow<RoleSelectState> = _state.asStateFlow()

    // SharedFlow(replay = 0) per PR #584 — buffered Channel could refire
    // NavigateToHome on a re-entry into RoleSelect after the user
    // backed out mid-RPC.
    private val _effects = kotlinx.coroutines.flow.MutableSharedFlow<AuthEffect>(
        extraBufferCapacity = 4,
    )
    val effects: kotlinx.coroutines.flow.Flow<AuthEffect> = _effects

    fun onRoleSelected(role: UserRole) {
        _state.update { it.copy(selected = role, form = it.form.copy(errorMessage = null)) }
    }

    fun onConfirm() {
        val current = _state.value
        val role = current.selected ?: return
        if (current.form.submitting) return
        _state.update { it.copy(form = FormUiState(submitting = true)) }
        viewModelScope.launch {
            val session = authRepository.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .first()
            profileRepository.updateRole(session.userId, role)
                .onSuccess {
                    userPrefs.setActiveRole(role.storageKey)
                    _state.update { it.copy(form = FormUiState()) }
                    _effects.emit(AuthEffect.NavigateToHome)
                }
                .onFailure { error ->
                    _state.update {
                        it.copy(form = FormUiState(errorMessage = error.toUserMessage()))
                    }
                }
        }
    }
}
