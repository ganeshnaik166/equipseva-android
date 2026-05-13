package com.equipseva.app.features.home

import android.app.Application
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.engineers.EngineerDirectoryRepository
import com.equipseva.app.core.data.engineers.EngineerRepository
import com.equipseva.app.core.data.cashsurvey.CashSurveyRepository
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
import javax.inject.Inject
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.firstOrNull
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
    private val spotAuditRepository: com.equipseva.app.core.data.spotaudit.SpotAuditRepository,
    private val amcRepository: com.equipseva.app.core.data.amc.AmcRepository,
    private val userPrefs: UserPrefs,
    private val app: Application,
) : ViewModel() {
    data class UiState(
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
        // PR-D1: post-completion cash-payment survey. Non-null when the
        // hospital has a completed job 24h..7d old without a survey row;
        // home renders a one-question bottom-sheet on the next foreground.
        val pendingCashSurvey: CashSurveyRepository.PendingSurvey? = null,
        // PR-D43 — random spot-audit invitation. Caller-scoped RPC
        // returns at most one open invitation per hospital.
        val pendingSpotAudit: com.equipseva.app.core.data.spotaudit.SpotAuditRepository.PendingInvitation? = null,
        val submittingSpotAudit: Boolean = false,
        // PR-D34: aggregated AMC SLA credits issued to hospital in the
        // trailing 30-day window. Card renders only when total > 0.
        val recentSlaCredits: com.equipseva.app.core.data.amc.AmcRepository.HospitalSlaCreditSummary? = null,
        // True when the signed-in profile has no phone number recorded.
        // Drives the hospital-side AddPhone banner — engineers can't
        // call the hospital during a job without it, and the badge
        // tucked away in Profile is invisible to a user who never
        // visits Profile.
        val phoneMissing: Boolean = false,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private var notifJob: Job? = null
    private var currentUserId: String? = null

    init {
        viewModelScope.launch {
            authRepository.sessionState.collect { session ->
                when (session) {
                    is AuthSession.SignedIn -> {
                        currentUserId = session.userId
                        refresh(session.userId)
                    }
                    is AuthSession.SignedOut -> {
                        notifJob?.cancel()
                        currentUserId = null
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
        //
        // Also rerun refresh when the cached role *changes* (multi-role
        // users tapping the new Profile → Account-type role-switch sheet).
        // The previous version only filled the role on null, so the home
        // hub kept rendering hospital tiles even after the bottom nav
        // flipped to engineer.
        viewModelScope.launch {
            userPrefs.activeRole.collect { key ->
                val cached = key?.let { k -> UserRole.entries.firstOrNull { it.storageKey == k } }
                if (cached != null && _state.value.role != cached) {
                    _state.update { it.copy(role = cached) }
                    currentUserId?.let { uid -> refresh(uid) }
                }
            }
        }
    }

    private suspend fun refresh(userId: String) {
        // Snapshot userPrefs ONCE per refresh — it's the source of
        // truth for "which role is the user currently rendering as".
        // The bottom nav, the role-editor sheet, and the auth roles-
        // confirm flow all write into it. The server profile.role can
        // be stale for a few hundred ms after the role-switch RPC
        // because Supabase returns the pre-update row in the cached
        // postgrest client unless we explicitly re-select.
        val prefsRoleKey = userPrefs.activeRole.firstOrNull()
        val prefsRole = prefsRoleKey?.let { k ->
            UserRole.entries.firstOrNull { it.storageKey == k }
        }
        profileRepository.fetchById(userId).onSuccess { profile ->
            // Prefer userPrefs over server fields. This keeps the home
            // hub aligned with the bottom nav after a Profile →
            // Account-type role switch (verified on Realme 2026-05-08:
            // server profile.role lagged userPrefs by one cold launch,
            // so the hospital tiles + greeting kept rendering even
            // after the user picked Field engineer + Save).
            val fetchedRole = prefsRole
                ?: profile?.activeRole
                ?: profile?.role
            _state.update {
                it.copy(
                    isFounder = profile?.isFounder() == true,
                    role = fetchedRole ?: it.role,
                    phoneMissing = profile?.phone.isNullOrBlank(),
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
            // PR-D43: spot-audit invitation (1-in-20 sample of completed
            // jobs). Quiet on errors; sheet just won't render.
            spotAuditRepository.fetchPending().onSuccess { pending ->
                _state.update { it.copy(pendingSpotAudit = pending) }
            }
            // PR-D34: pull hospital's recent AMC SLA credits summary.
            // Quiet on errors — card just won't render.
            amcRepository.hospitalRecentAmcSlaCredits().onSuccess { sum ->
                if (sum.totalCreditRupees > 0.0) {
                    _state.update { it.copy(recentSlaCredits = sum) }
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

    /**
     * Re-pull tiles + counts when the hospital returns to the hub
     * (post-job, post-bid-accept, post-completion). Without this the
     * "Open / Active / Engineers" hero strip and the loyalty/SLA
     * cards stay frozen at whatever they were when the session first
     * loaded.
     */
    fun refreshNow() {
        val uid = currentUserId ?: return
        viewModelScope.launch { refresh(uid) }
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
            val loc = fetchCurrentLocation(app)
            if (loc == null) {
                _state.update { it.copy(recommended = emptyList()) }
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
                    _state.update { it.copy(recommended = rows) }
                }
                .onFailure {
                    _state.update { it.copy(recommended = emptyList()) }
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

    /** PR-D43: submit spot audit response (rating 1..5 + free-text). */
    fun submitSpotAudit(rating: Int, feedback: String?) {
        val pending = _state.value.pendingSpotAudit ?: return
        if (_state.value.submittingSpotAudit) return
        _state.update { it.copy(submittingSpotAudit = true) }
        viewModelScope.launch {
            spotAuditRepository.submit(pending.invitationId, rating, feedback)
            _state.update {
                it.copy(submittingSpotAudit = false, pendingSpotAudit = null)
            }
        }
    }

    /** PR-D43: dismiss spot-audit sheet for this app open without recording. */
    fun dismissSpotAudit() {
        _state.update { it.copy(pendingSpotAudit = null) }
    }

}
