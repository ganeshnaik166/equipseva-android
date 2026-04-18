package com.equipseva.app.features.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
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
class HomeViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
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
        viewModelScope.launch {
            authRepository.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .distinctUntilChangedBy { it.userId }
                .collect { load(it.userId) }
        }
    }

    fun onRetry() {
        viewModelScope.launch {
            val current = authRepository.sessionState.first()
            if (current is AuthSession.SignedIn) {
                load(current.userId)
            }
        }
    }

    private suspend fun load(userId: String) {
        _state.update { it.copy(loading = true, errorMessage = null) }
        profileRepository.fetchById(userId)
            .onSuccess { profile ->
                _state.update {
                    it.copy(
                        loading = false,
                        greetingName = profile?.displayName ?: "there",
                        role = profile?.role,
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
