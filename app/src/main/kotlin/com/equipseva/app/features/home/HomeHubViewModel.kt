package com.equipseva.app.features.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.engineers.EngineerRepository
import com.equipseva.app.core.data.engineers.VerificationStatus
import com.equipseva.app.core.data.notifications.Notification
import com.equipseva.app.core.data.notifications.NotificationRepository
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.features.auth.UserRole
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * Backs HomeHubScreen with the bits Round C needs from Supabase: display
 * name, founder flag, the engineer's KYC status (drives the banner +
 * "Engineer Jobs" tile copy), the active role (drives signed-out vs
 * hospital vs engineer hero copy + stat strip), and the latest 3
 * notifications for the Recent Activity section.
 */
@HiltViewModel
class HomeHubViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
    private val engineerRepository: EngineerRepository,
    private val notificationRepository: NotificationRepository,
) : ViewModel() {
    data class UiState(
        val displayName: String? = null,
        val isFounder: Boolean = false,
        val role: UserRole? = null,
        val kycStatus: VerificationStatus? = null,
        val recent: List<Notification> = emptyList(),
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private var notifJob: Job? = null

    init {
        viewModelScope.launch {
            authRepository.sessionState.collect { session ->
                when (session) {
                    is AuthSession.SignedIn -> refresh(session.userId)
                    is AuthSession.SignedOut -> {
                        notifJob?.cancel()
                        _state.update { UiState() }
                    }
                    AuthSession.Unknown -> Unit
                }
            }
        }
    }

    private suspend fun refresh(userId: String) {
        profileRepository.fetchById(userId).onSuccess { profile ->
            _state.update {
                it.copy(
                    displayName = profile?.fullName,
                    isFounder = profile?.isFounder() == true,
                    role = profile?.activeRole ?: profile?.role,
                )
            }
        }
        if (_state.value.role == UserRole.ENGINEER) {
            engineerRepository.fetchByUserId(userId).onSuccess { eng ->
                if (eng != null) {
                    _state.update { it.copy(kycStatus = eng.verificationStatus) }
                }
            }
        }
        notifJob?.cancel()
        notifJob = viewModelScope.launch {
            notificationRepository.observeNotifications(userId)
                .catch { /* swallow stream errors — Recent Activity is informational */ }
                .collect { list ->
                    _state.update { it.copy(recent = list.take(3)) }
                }
        }
    }
}
