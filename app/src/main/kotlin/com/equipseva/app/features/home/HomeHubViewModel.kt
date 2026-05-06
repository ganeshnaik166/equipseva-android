package com.equipseva.app.features.home

import android.app.Application
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.engineers.EngineerDirectoryRepository
import com.equipseva.app.core.data.engineers.EngineerRepository
import com.equipseva.app.core.data.cashsurvey.CashSurveyRepository
import com.equipseva.app.core.data.commissiontier.CommissionTierRepository
import com.equipseva.app.core.data.engineers.VerificationStatus
import com.equipseva.app.core.data.notifications.Notification
import com.equipseva.app.core.data.notifications.NotificationRepository
import com.equipseva.app.core.data.prefs.UserPrefs
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.data.repair.RepairBidRepository
import com.equipseva.app.core.data.repair.RepairBidStatus
import com.equipseva.app.core.data.repair.RepairJobRepository
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.core.util.fetchCurrentLocation
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
    private val engineerDirectoryRepository: EngineerDirectoryRepository,
    private val cashSurveyRepository: CashSurveyRepository,
    private val commissionTierRepository: CommissionTierRepository,
    private val userPrefs: UserPrefs,
    private val app: Application,
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
        val nearbyEngineersCount: Int? = null,
        // PR-B: hospital-only carousel of top-N engineers ranked by
        // server-side match_score (proximity + specialization + rating).
        // Empty until GPS resolves AND the RPC returns ≥1 row — caller
        // hides the section gracefully so we never show an empty band.
        val recommended: List<EngineerDirectoryRepository.RecommendedRow> = emptyList(),
        val recommendedLoading: Boolean = false,
        // PR-D1: post-completion cash-payment survey. Non-null when the
        // hospital has a completed job 24h..7d old without a survey row;
        // home renders a one-question bottom-sheet on the next foreground.
        val pendingCashSurvey: CashSurveyRepository.PendingSurvey? = null,
        // PR-D15: hospital loyalty progress pill — non-null when the
        // get_my_commission_tier RPC returns a row.
        val commissionTier: CommissionTierRepository.TierInfo? = null,
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
        // Fresh signups race the profiles row trigger: HomeHub can fetch
        // before profiles.role is populated and end up rendering the
        // engineer fallback for a hospital user. UserPrefs.activeRole is
        // written on signup / role-confirm and survives across launches,
        // so observe it as a fallback when the profile fetch hasn't yet
        // resolved a role — keeps the tiles + KYC banner aligned with the
        // bottom-nav (which already reads from this prefs key).
        viewModelScope.launch {
            userPrefs.activeRole.collect { key ->
                val cached = key?.let { k -> UserRole.entries.firstOrNull { it.storageKey == k } }
                if (cached != null && _state.value.role == null) {
                    _state.update { it.copy(role = cached) }
                }
            }
        }
    }

    private suspend fun refresh(userId: String) {
        profileRepository.fetchById(userId).onSuccess { profile ->
            // Don't clobber a role we already resolved (eg. via UserPrefs)
            // when the profile fetch returns a row without a role yet — that
            // happens during the trigger / updateRole race after fresh signup
            // and would flip the tiles to engineer for a hospital user.
            val fetchedRole = profile?.activeRole ?: profile?.role
            _state.update {
                it.copy(
                    displayName = profile?.fullName,
                    isFounder = profile?.isFounder() == true,
                    role = fetchedRole ?: it.role,
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
            // Hospital hero strip: open + in-progress job counts +
            // verified engineers visible in the directory. The engineers
            // count uses an unfiltered search (limit caps at 200) so it
            // reads the platform-wide pool, not a per-district slice.
            val jobs = jobRepository.fetchByHospitalUser(userId).getOrNull().orEmpty()
            val open = jobs.count { it.status == RepairJobStatus.Requested }
            val active = jobs.count {
                it.status in listOf(
                    RepairJobStatus.Assigned,
                    RepairJobStatus.EnRoute,
                    RepairJobStatus.InProgress,
                )
            }
            val engineers = engineerDirectoryRepository.search(limit = 200)
                .getOrNull()?.size
            _state.update {
                it.copy(
                    openCount = open,
                    activeCount = active,
                    nearbyEngineersCount = engineers,
                )
            }
            // PR-B: kick off the recommended-engineers carousel fetch.
            // Best-effort: GPS may not be granted, the RPC may return
            // zero rows, etc. — the UI just hides the section.
            loadRecommendedCarousel()
            // PR-D1: ask the cash-survey RPC whether a completed job
            // is awaiting feedback. Quiet on errors — the bottom-sheet
            // simply doesn't appear if the call fails.
            cashSurveyRepository.fetchPending().onSuccess { pending ->
                _state.update { it.copy(pendingCashSurvey = pending) }
            }
            // PR-D15: pull the hospital's commission-tier progress
            // (PR-D2 RPC). Quiet on errors — pill just won't render.
            commissionTierRepository.fetchMyTier().onSuccess { tier ->
                _state.update { it.copy(commissionTier = tier) }
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

    /**
     * PR-B: pull top-N recommended engineers for the hospital home
     * carousel. Requires GPS — when permission is missing or no fix
     * arrives within the timeout, [recommended] stays empty and the
     * UI falls back to the static "Book a repair engineer" tile.
     * Equipment category is left null on the home call (no per-job
     * context); the SQL ranks on proximity + rating only.
     */
    private fun loadRecommendedCarousel() {
        viewModelScope.launch {
            _state.update { it.copy(recommendedLoading = true) }
            val loc = fetchCurrentLocation(app)
            if (loc == null) {
                _state.update { it.copy(recommendedLoading = false, recommended = emptyList()) }
                return@launch
            }
            engineerDirectoryRepository
                .recommendedEngineers(
                    hospitalLat = loc.latitude,
                    hospitalLng = loc.longitude,
                    equipmentCategory = null,
                    limit = 5,
                )
                .onSuccess { rows ->
                    _state.update { it.copy(recommendedLoading = false, recommended = rows) }
                }
                .onFailure {
                    _state.update { it.copy(recommendedLoading = false, recommended = emptyList()) }
                }
        }
    }

    /**
     * PR-D1: hospital answered the one-question cash-payment survey.
     * Posts to the RPC and clears the pending row regardless of result —
     * the worst case is we re-prompt next foreground (idempotent on the
     * server via the unique repair_job_id).
     */
    fun submitCashSurvey(response: CashSurveyRepository.Response) {
        val pending = _state.value.pendingCashSurvey ?: return
        viewModelScope.launch {
            cashSurveyRepository.submit(pending.repairJobId, response)
            _state.update { it.copy(pendingCashSurvey = null) }
        }
    }

    /** PR-D1: dismiss the cash survey for this app open without recording. */
    fun dismissCashSurvey() {
        _state.update { it.copy(pendingCashSurvey = null) }
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
