package com.equipseva.app.features.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.profile.ProfileRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * Tiny VM behind HomeHubScreen. Reads the signed-in user's profile so the
 * Hub can greet them by name and conditionally surface the Founder admin
 * tile. Falls back to a generic welcome when signed-out.
 */
@HiltViewModel
class HomeHubViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
) : ViewModel() {
    data class UiState(
        val displayName: String? = null,
        val isFounder: Boolean = false,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init {
        viewModelScope.launch {
            authRepository.sessionState.collect { session ->
                when (session) {
                    is AuthSession.SignedIn -> refresh(session.userId)
                    is AuthSession.SignedOut -> _state.update { UiState() }
                    AuthSession.Unknown -> Unit
                }
            }
        }
    }

    private suspend fun refresh(userId: String) {
        profileRepository.fetchById(userId)
            .onSuccess { profile ->
                _state.update {
                    it.copy(
                        displayName = profile?.fullName,
                        isFounder = profile?.isFounder() == true,
                    )
                }
            }
    }
}
