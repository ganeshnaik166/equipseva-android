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
import com.equipseva.app.core.data.repair.RepairBidRepository
import com.equipseva.app.core.data.repair.RepairBidStatus
import com.equipseva.app.core.data.repair.RepairJobRepository
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.features.auth.UserRole
import dagger.hilt.android.lifecycle.HiltViewModel
import java.time.Instant
import java.time.temporal.ChronoUnit
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
    private val jobRepository: RepairJobRepository,
    private val bidRepository: RepairBidRepository,
) : ViewModel() {
    data class UiState(
        val displayName: String? = null,
        val isFounder: Boolean = false,
        val role: UserRole? = null,
        val kycStatus: VerificationStatus? = null,
        val recent: List<Notification> = emptyList(),
        // Hero stat strip (per-role; null = "—" placeholder)
        val openCount: Int? = null,
        val activeCount: Int? = null,
        val pendingBidsCount: Int? = null,
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
            // Engineer hero strip: pending bids + active assigned jobs.
            // "Nearby" left as "—" until a per-radius RPC stream lands here.
            val pendingBids = bidRepository.fetchMyBids().getOrNull()
                ?.count { it.status == RepairBidStatus.Pending }
            val activeMine = jobRepository.fetchAssignedToMe().getOrNull()
                ?.count {
                    it.status in listOf(
                        RepairJobStatus.Assigned,
                        RepairJobStatus.EnRoute,
                        RepairJobStatus.InProgress,
                    )
                }
            _state.update {
                it.copy(pendingBidsCount = pendingBids, activeCount = activeMine)
            }
        } else if (_state.value.role == UserRole.HOSPITAL) {
            // Hospital hero strip: open + in-progress job counts.
            val jobs = jobRepository.fetchByHospitalUser(userId).getOrNull().orEmpty()
            val open = jobs.count { it.status == RepairJobStatus.Requested }
            val active = jobs.count {
                it.status in listOf(
                    RepairJobStatus.Assigned,
                    RepairJobStatus.EnRoute,
                    RepairJobStatus.InProgress,
                )
            }
            _state.update { it.copy(openCount = open, activeCount = active) }
        }
        notifJob?.cancel()
        notifJob = viewModelScope.launch {
            notificationRepository.observeNotifications(userId)
                .catch { /* swallow stream errors — Recent Activity is informational */ }
                .collect { list ->
                    val recent = if (list.isEmpty()) {
                        // Round-3 design preview — seed Recent Activity with
                        // role-tinted dummies so the section is visible while
                        // the real notification stream is empty. Replaced
                        // automatically once real notifications land.
                        sampleRecent(userId, _state.value.role)
                    } else {
                        list.take(3)
                    }
                    _state.update { it.copy(recent = recent) }
                }
        }
    }

    private fun sampleRecent(userId: String, role: UserRole?): List<Notification> {
        val now = Instant.now()
        return if (role == UserRole.HOSPITAL) {
            listOf(
                Notification(
                    id = "sample-bid",
                    userId = userId,
                    title = "New bid on RJ-2026-0419 — ₹2,200 from Satish Naidu",
                    body = "Tap to review",
                    kind = "bid",
                    data = emptyMap(),
                    sentAt = now.minus(8, ChronoUnit.MINUTES),
                    readAt = null,
                    deepLink = null,
                ),
                Notification(
                    id = "sample-msg",
                    userId = userId,
                    title = "Satish Naidu: On my way, eta 15 min.",
                    body = "Tap to open chat",
                    kind = "msg",
                    data = emptyMap(),
                    sentAt = now.minus(12, ChronoUnit.MINUTES),
                    readAt = null,
                    deepLink = null,
                ),
                Notification(
                    id = "sample-status",
                    userId = userId,
                    title = "Job RJ-2026-0416 marked In Progress",
                    body = "Tap to track",
                    kind = "status",
                    data = emptyMap(),
                    sentAt = now.minus(1, ChronoUnit.HOURS),
                    readAt = now,
                    deepLink = null,
                ),
            )
        } else {
            listOf(
                Notification(
                    id = "sample-job",
                    userId = userId,
                    title = "New job nearby — BPL Cleo 70 PM at Sri Sai Hospital",
                    body = "Tap to bid",
                    kind = "bolt",
                    data = emptyMap(),
                    sentAt = now.minus(6, ChronoUnit.MINUTES),
                    readAt = null,
                    deepLink = null,
                ),
                Notification(
                    id = "sample-accepted",
                    userId = userId,
                    title = "Your bid on RJ-2026-0418 was accepted",
                    body = "₹2,500 · Tap to view",
                    kind = "bid",
                    data = emptyMap(),
                    sentAt = now.minus(40, ChronoUnit.MINUTES),
                    readAt = null,
                    deepLink = null,
                ),
                Notification(
                    id = "sample-payout",
                    userId = userId,
                    title = "Payout ₹3,400 settled to your bank",
                    body = "Tap to download invoice",
                    kind = "bid",
                    data = emptyMap(),
                    sentAt = now.minus(2, ChronoUnit.HOURS),
                    readAt = now,
                    deepLink = null,
                ),
            )
        }
    }
}
