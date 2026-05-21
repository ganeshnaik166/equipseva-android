package com.equipseva.app.features.repair.directory

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Chat
import androidx.compose.material.icons.outlined.Security
import androidx.compose.material.icons.outlined.Verified
import androidx.compose.material.icons.outlined.Inbox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.engineers.EngineerDirectoryRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.core.util.initialsOf
import com.equipseva.app.core.util.prettyKey
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsSection
import com.equipseva.app.designsystem.components.InlineStars
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.Paper2
import com.equipseva.app.designsystem.theme.Paper3
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen100
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInfo50
import com.equipseva.app.designsystem.theme.SevaInfo500
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk600
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.designsystem.components.EsChip
import com.equipseva.app.features.repair.components.CallConnectingDialog
import com.equipseva.app.features.repair.components.MaskedContactPanel
import com.equipseva.app.features.repair.components.RepeatBookingNudge
import com.equipseva.app.features.repair.components.ServiceAreaMap
import com.equipseva.app.navigation.Routes
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class EngineerPublicProfileViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val repo: EngineerDirectoryRepository,
    private val authRepository: com.equipseva.app.core.auth.AuthRepository,
    private val chatRepository: com.equipseva.app.core.data.chat.ChatRepository,
    private val virtualCallRepository: com.equipseva.app.core.data.calls.VirtualCallRepository,
    private val repairJobRepository: com.equipseva.app.core.data.repair.RepairJobRepository,
    private val userPrefs: com.equipseva.app.core.data.prefs.UserPrefs,
    private val app: android.app.Application,
) : ViewModel() {
    private val engineerId: String = savedStateHandle[Routes.ENGINEER_PUBLIC_PROFILE_ARG_ID] ?: ""

    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val profile: EngineerDirectoryRepository.PublicProfile? = null,
        val openingChat: Boolean = false,
        val reviews: List<EngineerDirectoryRepository.EngineerReview> = emptyList(),
        val reviewsLoading: Boolean = false,
        // PR-B: per-category review aggregates rendered as pills above
        // the Reviews section. Empty until the RPC returns.
        val reviewCategorySummary: List<EngineerDirectoryRepository.CategoryReviewSummary> = emptyList(),
        // PR-B: alternatives shown by the repeat-booking nudge when
        // this engineer is far away AND viewer has booked them before.
        // Empty unless the nudge gate is active.
        val nudgeAlternatives: List<EngineerDirectoryRepository.RecommendedRow> = emptyList(),
        val nudgeDistanceKm: Double? = null,
        val nudgeDismissed: Boolean = false,
        // v2 phone-masking — set while request-call-session is in
        // flight + while we hold the dialog open after a successful
        // bridge so the user can read the "your phone will ring" copy.
        val callBusy: Boolean = false,
        val callConnectingMessage: String? = null,
        // True when the signed-in viewer's active role is hospital — only
        // hospitals book + call engineers, so the masked-call panel is
        // hospital-only. Engineer-to-engineer profile browse just sees the
        // privacy disclosure box.
        val viewerIsHospital: Boolean = false,
        // Most recent in-flight job between viewer (hospital) + this
        // engineer in (assigned, en_route, in_progress). Required by the
        // server-side participants_for_repair_job RPC — calls are scoped
        // to a job. Null means viewer has no active job → tap Call routes
        // them to chat first.
        val activeRepairJobId: String? = null,
        // True when the signed-in viewer is the engineer being viewed —
        // engineer Profile → "Preview public profile" route. We hide the
        // sticky Message/Post-job/Set-maintenance CTAs in that case so
        // the screen reads as a read-only preview ("how hospitals see
        // me"). Tapping Message would open chat with self; tapping
        // "Post a repair job" would land on the hospital-only wizard.
        val isSelfPreview: Boolean = false,
    )

    sealed interface Effect {
        data class NavigateToChat(val conversationId: String) : Effect
        data class ShowMessage(val text: String) : Effect
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private val _effects = kotlinx.coroutines.channels.Channel<Effect>(kotlinx.coroutines.channels.Channel.BUFFERED)
    val effects = _effects.receiveAsFlow()

    init {
        viewModelScope.launch {
            // Fail fast on malformed deep-links (`/engineer/<garbage>`
            // landed here with engineerId = "" before) — without this the
            // RPC fetches a blank profile, which renders as "Couldn't
            // load" with no signal that the deep link itself was bad.
            if (engineerId.isBlank()) {
                _state.update {
                    it.copy(loading = false, error = "Couldn't open that engineer — the link looks invalid.")
                }
                return@launch
            }
            // Dummy profiles are seed data for the directory's design
            // mocks. In release builds we never want a hardcoded entry to
            // mask a real backend failure during QA, so gate the lookup
            // to debug — production always hits the RPC and surfaces real
            // errors via toUserMessage().
            val dummy = if (com.equipseva.app.BuildConfig.DEBUG) DUMMY_PUBLIC_PROFILES[engineerId] else null
            if (dummy != null) {
                _state.update { it.copy(loading = false, profile = dummy) }
                return@launch
            }
            repo.fetchPublicProfile(engineerId)
                .onSuccess { p -> _state.update { it.copy(loading = false, profile = p) } }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.toUserMessage()) } }
            // Reviews are best-effort: a failure here doesn't blank the
            // whole profile — the rating-card still renders aggregates.
            _state.update { it.copy(reviewsLoading = true) }
            repo.fetchRecentReviews(engineerId, limit = 10)
                .onSuccess { rows -> _state.update { it.copy(reviewsLoading = false, reviews = rows) } }
                .onFailure { _state.update { it.copy(reviewsLoading = false) } }
            // PR-B: per-category aggregates for the pills row. Failure
            // is silent — pills row collapses to nothing.
            repo.fetchReviewSummaryByCategory(engineerId)
                .onSuccess { rows -> _state.update { it.copy(reviewCategorySummary = rows) } }
            resolveCallContext()
            evaluateRepeatBookingNudge()
        }
    }

    /**
     * v2.1 follow-up to PR-B: real frequency rule for the repeat-booking
     * nudge. Fires when:
     *   - viewer is a hospital (UserPrefs.activeRole)
     *   - this engineer's base coords are known
     *   - device GPS resolves
     *   - count_completed_jobs_with_engineer(engineerId) >= 3
     *   - haversine(viewer, engineer) >= 50 km
     * On match, fetches top-3 recommended local engineers (excluding
     * this one) and primes the nudge state. Failures are silent — the
     * nudge just doesn't appear.
     */
    private suspend fun evaluateRepeatBookingNudge() {
        val role = runCatching { userPrefs.activeRole.first() }.getOrNull()
        if (role != com.equipseva.app.features.auth.UserRole.HOSPITAL.storageKey) return
        val profile = _state.value.profile ?: return
        val engBaseLat = profile.baseLatitude ?: return
        val engBaseLng = profile.baseLongitude ?: return

        val coords = runCatching {
            com.equipseva.app.core.util.fetchCurrentLocation(app)
        }.getOrNull() ?: return
        val distanceKm = haversineKm(coords.latitude, coords.longitude, engBaseLat, engBaseLng)
        if (distanceKm < 50.0) return

        val count = repo.countCompletedJobsWithEngineer(engineerId).getOrNull() ?: 0
        if (count < 3) return

        val alternatives = repo.recommendedEngineers(
            hospitalLat = coords.latitude,
            hospitalLng = coords.longitude,
            equipmentCategory = null,
            limit = 5,
        ).getOrNull().orEmpty()
            .filter { it.engineerId != engineerId }
            .take(3)
        if (alternatives.isEmpty()) return

        primeRepeatBookingNudge(distanceKm, alternatives)
    }

    private fun haversineKm(
        lat1: Double, lng1: Double, lat2: Double, lng2: Double,
    ): Double = com.equipseva.app.features.repair.directory.haversineKm(lat1, lng1, lat2, lng2)

    /**
     * Resolve role + most-recent active job between viewer and this
     * engineer. Best-effort: any failure leaves callEnabled=false, the
     * masked panel falls through to the chat-only path. We never block
     * profile render on this.
     */
    private suspend fun resolveCallContext() {
        val role = runCatching { userPrefs.activeRole.first() }.getOrNull()
        val isHospital = role == com.equipseva.app.features.auth.UserRole.HOSPITAL.storageKey
        val viewerUserId = authRepository.sessionState
            .filterIsInstance<com.equipseva.app.core.auth.AuthSession.SignedIn>()
            .firstOrNull()?.userId
        // Engineer previewing own profile from Profile → "Preview public
        // profile" — flag so the sticky CTA bar hides. Profile body still
        // renders, just without the hospital-targeted actions.
        val profileUserId = _state.value.profile?.userId
        val isSelf = !viewerUserId.isNullOrBlank() &&
            !profileUserId.isNullOrBlank() &&
            viewerUserId == profileUserId
        if (!isHospital || viewerUserId.isNullOrBlank()) {
            _state.update { it.copy(viewerIsHospital = isHospital, isSelfPreview = isSelf) }
            return
        }
        val activeId = runCatching {
            repairJobRepository.fetchByHospitalUser(viewerUserId).getOrNull().orEmpty()
                .filter {
                    it.engineerId == engineerId &&
                        it.status in ACTIVE_STATUSES_FOR_CALL
                }
                .maxByOrNull { it.createdAtInstant ?: java.time.Instant.EPOCH }
                ?.id
        }.getOrNull()
        _state.update { it.copy(viewerIsHospital = true, activeRepairJobId = activeId, isSelfPreview = isSelf) }
    }

    private companion object {
        val ACTIVE_STATUSES_FOR_CALL = setOf(
            com.equipseva.app.core.data.repair.RepairJobStatus.Assigned,
            com.equipseva.app.core.data.repair.RepairJobStatus.EnRoute,
            com.equipseva.app.core.data.repair.RepairJobStatus.InProgress,
        )
    }

    fun openChatWithEngineer() {
        val peerId = _state.value.profile?.userId
        if (peerId.isNullOrBlank() || _state.value.openingChat) return
        _state.update { it.copy(openingChat = true) }
        viewModelScope.launch {
            val session = authRepository.sessionState
                .filterIsInstance<com.equipseva.app.core.auth.AuthSession.SignedIn>()
                .firstOrNull()
            val selfId = session?.userId
            if (selfId == null) {
                _state.update { it.copy(openingChat = false) }
                _effects.send(Effect.ShowMessage("Please sign in to start a chat"))
                return@launch
            }
            if (selfId == peerId) {
                _state.update { it.copy(openingChat = false) }
                _effects.send(Effect.ShowMessage("This is your own profile"))
                return@launch
            }
            chatRepository.getOrCreateDirect(selfUserId = selfId, peerUserId = peerId).fold(
                onSuccess = { convo ->
                    _state.update { it.copy(openingChat = false) }
                    _effects.send(Effect.NavigateToChat(convo.id))
                },
                onFailure = { ex ->
                    _state.update { it.copy(openingChat = false) }
                    _effects.send(Effect.ShowMessage(ex.toUserMessage()))
                },
            )
        }
    }

    /**
     * Trigger the masked-call bridge for the most recent active job
     * shared with this engineer. Caller is the hospital — the bridge
     * dials both legs from EquipSeva's ExoPhone via Exotel. While
     * Exotel onboarding is still in progress server-side, the edge
     * function returns ProviderNotConfigured and we surface a "calls
     * coming soon" snackbar instead of crashing.
     *
     * The repairJobId is the only required input — server validates
     * caller participation. Resolving "which job to attach the call
     * to" is the caller's responsibility (typically the most recent
     * Assigned/EnRoute/InProgress job; null if none). When null we
     * tell the user to start a job first.
     */
    fun startMaskedCall(repairJobId: String?) {
        if (_state.value.callBusy) return
        if (repairJobId.isNullOrBlank()) {
            viewModelScope.launch {
                _effects.send(
                    Effect.ShowMessage("Open a chat or book a job to start a call."),
                )
            }
            return
        }
        _state.update { it.copy(callBusy = true) }
        viewModelScope.launch {
            virtualCallRepository.requestCallSession(repairJobId)
                .onSuccess { result ->
                    when (result) {
                        is com.equipseva.app.core.data.calls.CallSessionResult.ClickToCall ->
                            _state.update {
                                it.copy(callBusy = false, callConnectingMessage = result.message)
                            }
                        com.equipseva.app.core.data.calls.CallSessionResult.ProviderNotConfigured -> {
                            _state.update { it.copy(callBusy = false, callConnectingMessage = null) }
                            _effects.send(
                                Effect.ShowMessage("In-app calls coming soon — chat for now."),
                            )
                        }
                        is com.equipseva.app.core.data.calls.CallSessionResult.RateLimited -> {
                            _state.update { it.copy(callBusy = false) }
                            _effects.send(Effect.ShowMessage(result.message))
                        }
                        com.equipseva.app.core.data.calls.CallSessionResult.MissingPhone -> {
                            _state.update { it.copy(callBusy = false) }
                            _effects.send(
                                Effect.ShowMessage("Engineer hasn't added a phone yet. Use chat instead."),
                            )
                        }
                        com.equipseva.app.core.data.calls.CallSessionResult.NotParticipant -> {
                            _state.update { it.copy(callBusy = false) }
                            _effects.send(
                                Effect.ShowMessage("Open a chat first — calls are scoped to active jobs."),
                            )
                        }
                        is com.equipseva.app.core.data.calls.CallSessionResult.Error -> {
                            _state.update { it.copy(callBusy = false) }
                            _effects.send(Effect.ShowMessage(result.message))
                        }
                    }
                }
                .onFailure { ex ->
                    _state.update { it.copy(callBusy = false) }
                    _effects.send(Effect.ShowMessage(ex.toUserMessage()))
                }
        }
    }

    fun dismissCallConnecting() {
        _state.update { it.copy(callConnectingMessage = null) }
    }

    /**
     * PR-B test trigger for the repeat-booking nudge. The real frequency
     * rule (booked >=3 times AND >50km) is a follow-up. For now the caller
     * (eg. an internal QA toggle) hands us the engineer's distance + a
     * pre-fetched alternatives list and the component renders.
     *
     * The hospital coords used to compute distance and alternatives must
     * be resolved by the caller; we don't refetch GPS here so the nudge
     * stays cheap to mount.
     */
    fun primeRepeatBookingNudge(
        engineerDistanceKm: Double,
        alternatives: List<EngineerDirectoryRepository.RecommendedRow>,
    ) {
        if (engineerDistanceKm < 50.0) return
        _state.update {
            it.copy(
                nudgeAlternatives = alternatives,
                nudgeDistanceKm = engineerDistanceKm,
                nudgeDismissed = false,
            )
        }
    }

    fun dismissRepeatBookingNudge() {
        _state.update { it.copy(nudgeDismissed = true) }
    }
}

private val DUMMY_PUBLIC_PROFILES: Map<String, EngineerDirectoryRepository.PublicProfile> = mapOf(
    "dummy-eng-1" to EngineerDirectoryRepository.PublicProfile(
        engineerId = "dummy-eng-1",
        userId = null,
        fullName = "Satish Naidu",
        avatarUrl = null,
        phone = "+91 98••• ••321",
        email = null,
        city = "Nalgonda",
        state = "Telangana",
        serviceAreas = listOf("Nalgonda", "Suryapet"),
        specializations = listOf("Patient Monitors", "Ventilators", "Defibrillators"),
        brandsServiced = listOf("Philips", "GE", "Mindray"),
        oemTrainingBadges = listOf("Philips IntelliVue", "GE CARESCAPE"),
        experienceYears = 8,
        ratingAvg = 4.9,
        totalJobs = 142,
        completionRate = 98.0,
        hourlyRate = 1500.0,
        bio = "Independent biomedical engineer with 8 years experience servicing critical-care equipment across Nalgonda and Suryapet districts. Same-day onsite for ICU/OT equipment.",
        isAvailable = true,
        baseLatitude = null,
        baseLongitude = null,
        serviceRadiusKm = 30,
    ),
    "dummy-eng-2" to EngineerDirectoryRepository.PublicProfile(
        engineerId = "dummy-eng-2",
        userId = null,
        fullName = "Priyanka Reddy",
        avatarUrl = null,
        phone = "+91 98••• ••456",
        email = null,
        city = "Nalgonda",
        state = "Telangana",
        serviceAreas = listOf("Nalgonda"),
        specializations = listOf("Surgical", "Anaesthesia", "OT equipment"),
        brandsServiced = listOf("Drager", "Medtronic"),
        oemTrainingBadges = listOf("Drager Anaesthesia"),
        experienceYears = 6,
        ratingAvg = 4.8,
        totalJobs = 67,
        completionRate = 100.0,
        hourlyRate = 1400.0,
        bio = "Specialist in OT and anaesthesia equipment. Certified by Drager. 6 years across multi-specialty hospitals in Nalgonda.",
        isAvailable = true,
        baseLatitude = null,
        baseLongitude = null,
        serviceRadiusKm = 20,
    ),
    "dummy-eng-3" to EngineerDirectoryRepository.PublicProfile(
        engineerId = "dummy-eng-3",
        userId = null,
        fullName = "Arjun Varma",
        avatarUrl = null,
        phone = "+91 98••• ••782",
        email = null,
        city = "Nalgonda",
        state = "Telangana",
        serviceAreas = listOf("Nalgonda"),
        specializations = listOf("Imaging", "Ultrasound", "X-ray"),
        brandsServiced = listOf("Siemens", "GE"),
        oemTrainingBadges = listOf("Siemens MRI"),
        experienceYears = 10,
        ratingAvg = 4.7,
        totalJobs = 203,
        completionRate = 96.0,
        hourlyRate = 1800.0,
        bio = "Senior imaging engineer — MRI/CT/ultrasound. 10 years across Telangana. Currently busy through next week.",
        isAvailable = false,
        baseLatitude = null,
        baseLongitude = null,
        serviceRadiusKm = 50,
    ),
    "dummy-eng-4" to EngineerDirectoryRepository.PublicProfile(
        engineerId = "dummy-eng-4",
        userId = null,
        fullName = "Lakshmi Devi",
        avatarUrl = null,
        phone = "+91 98••• ••109",
        email = null,
        city = "Suryapet",
        state = "Telangana",
        serviceAreas = listOf("Suryapet", "Nalgonda"),
        specializations = listOf("Laboratory", "Centrifuges", "Analyzers"),
        brandsServiced = listOf("Roche", "Beckman"),
        oemTrainingBadges = emptyList(),
        experienceYears = 5,
        ratingAvg = 4.6,
        totalJobs = 54,
        completionRate = 94.0,
        hourlyRate = 1200.0,
        bio = "Lab equipment specialist — centrifuges, analyzers, biochem. Covers Suryapet/Nalgonda.",
        isAvailable = true,
        baseLatitude = null,
        baseLongitude = null,
        serviceRadiusKm = 40,
    ),
)

@Composable
fun EngineerPublicProfileScreen(
    onBack: () -> Unit,
    onRequestService: (engineerId: String) -> Unit,
    onOpenConversation: (conversationId: String) -> Unit = {},
    onShowMessage: (String) -> Unit = {},
    onSetupMaintenance: (engineerId: String) -> Unit = {},
    viewModel: EngineerPublicProfileViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    LaunchedEffect(viewModel) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is EngineerPublicProfileViewModel.Effect.NavigateToChat ->
                    onOpenConversation(effect.conversationId)
                is EngineerPublicProfileViewModel.Effect.ShowMessage ->
                    onShowMessage(effect.text)
            }
        }
    }
    state.callConnectingMessage?.let { msg ->
        // Once the bridge POST returns 200 the user's phone is already
        // ringing — hold the dialog ~4s so they can read the privacy
        // copy, then auto-dismiss. Cancel button + onDismissRequest
        // both call dismissCallConnecting() too.
        LaunchedEffect(msg) {
            delay(4000)
            viewModel.dismissCallConnecting()
        }
        CallConnectingDialog(
            message = msg,
            onCancel = { viewModel.dismissCallConnecting() },
        )
    }
    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(
                title = "Engineer",
                onBack = onBack,
                // Share icon was wired to a `/* share */` no-op comment.
                // Same dead-control pattern as the chat header phone +
                // the AssignedEngineerCard call button. Dropped until a
                // real share intent (deep-link to engineer profile) is
                // wired — there's no public web URL yet anyway.
            )
            Box(modifier = Modifier.weight(1f)) {
                when {
                    state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                    state.profile == null -> EmptyStateView(
                        icon = Icons.Outlined.Inbox,
                        title = "Profile unavailable",
                        subtitle = state.error ?: "This engineer is no longer listed.",
                    )
                    else -> ProfileBody(
                        p = state.profile!!,
                        viewerIsHospital = state.viewerIsHospital,
                        activeRepairJobId = state.activeRepairJobId,
                        callBusy = state.callBusy,
                        chatBusy = state.openingChat,
                        onCall = { viewModel.startMaskedCall(state.activeRepairJobId) },
                        onOpenChat = { viewModel.openChatWithEngineer() },
                        reviews = state.reviews,
                        reviewsLoading = state.reviewsLoading,
                        categorySummary = state.reviewCategorySummary,
                        nudgeAlternatives = if (state.nudgeDismissed) emptyList() else state.nudgeAlternatives,
                        nudgeDistanceKm = state.nudgeDistanceKm,
                        onPickAlternative = { id ->
                            viewModel.dismissRepeatBookingNudge()
                            // nav handled at top-level via onRequestService
                            // -ish path is OK; here we just dismiss and let
                            // the caller's onRequestService relaunch the
                            // profile route for the picked engineer.
                            onRequestService(id)
                        },
                        onDismissNudge = { viewModel.dismissRepeatBookingNudge() },
                    )
                }
            }
            // Sticky CTA bar — hidden during self-preview (engineer
            // tapped "Preview public profile" from their own Profile).
            // The hospital-targeted actions don't apply when viewing
            // yourself, and the screen reads better as a clean preview.
            if (state.profile != null && !state.isSelfPreview) {
                Surface(color = Color.White) {
                    Column(modifier = Modifier.fillMaxWidth()) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(1.dp)
                                .background(BorderDefault),
                        )
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp, vertical = 12.dp),
                            horizontalArrangement = Arrangement.spacedBy(10.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            EsBtn(
                                text = if (state.openingChat) "Opening…" else "Message",
                                onClick = { viewModel.openChatWithEngineer() },
                                kind = EsBtnKind.Secondary,
                                size = EsBtnSize.Lg,
                                disabled = state.openingChat,
                                leading = {
                                    Icon(
                                        Icons.AutoMirrored.Outlined.Chat,
                                        contentDescription = null,
                                        tint = SevaInk700,
                                        modifier = Modifier.size(16.dp),
                                    )
                                },
                            )
                            Box(modifier = Modifier.weight(1f)) {
                                EsBtn(
                                    // "Request this engineer" overpromised —
                                    // tapping it opens the generic 4-step
                                    // post-job wizard which broadcasts to
                                    // every eligible engineer in radius,
                                    // not a private invitation to this one.
                                    // Rename until backend supports
                                    // engineer-targeted RFQs (anti-leak v2).
                                    text = "Post a repair job",
                                    onClick = { onRequestService(state.profile!!.engineerId) },
                                    kind = EsBtnKind.Primary,
                                    size = EsBtnSize.Lg,
                                    full = true,
                                )
                            }
                        }
                        // PR-C6 secondary CTA — only hospitals see this.
                        // Engineers browsing other engineers don't book
                        // AMC contracts so the row is suppressed in
                        // that case.
                        if (state.viewerIsHospital) {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 16.dp)
                                    .padding(bottom = 12.dp),
                            ) {
                                Box(modifier = Modifier.weight(1f)) {
                                    EsBtn(
                                        text = "Set up monthly maintenance",
                                        onClick = {
                                            onSetupMaintenance(state.profile!!.engineerId)
                                        },
                                        kind = EsBtnKind.Lime,
                                        size = EsBtnSize.Lg,
                                        full = true,
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ProfileBody(
    p: EngineerDirectoryRepository.PublicProfile,
    viewerIsHospital: Boolean,
    activeRepairJobId: String?,
    callBusy: Boolean,
    chatBusy: Boolean,
    onCall: () -> Unit,
    onOpenChat: () -> Unit,
    reviews: List<EngineerDirectoryRepository.EngineerReview>,
    reviewsLoading: Boolean,
    categorySummary: List<EngineerDirectoryRepository.CategoryReviewSummary>,
    nudgeAlternatives: List<EngineerDirectoryRepository.RecommendedRow>,
    nudgeDistanceKm: Double?,
    onPickAlternative: (engineerId: String) -> Unit,
    onDismissNudge: () -> Unit,
) {
    val hasRelationship = !p.phone.isNullOrBlank() || !p.email.isNullOrBlank()
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
    ) {
        // Hero block — white bg + 1dp bottom border, padding 8/16/16
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(Color.White)
                .padding(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 16.dp),
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(14.dp),
                verticalAlignment = Alignment.Top,
            ) {
                AvatarBlock(
                    initials = initialsOf(p.fullName),
                    avatarUrl = p.avatarUrl,
                    size = 64.dp,
                    online = p.isAvailable,
                )
                Column(modifier = Modifier.weight(1f)) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        Text(
                            p.fullName,
                            color = SevaInk900,
                            fontSize = 18.sp,
                            fontWeight = FontWeight.Bold,
                        )
                        InlineVerifiedBadge(small = false)
                    }
                    val locLine = listOfNotNull(
                        p.city?.takeIf { it.isNotBlank() },
                        p.state?.takeIf { it.isNotBlank() },
                    ).joinToString(", ")
                    if (locLine.isNotBlank()) {
                        Spacer(Modifier.height(4.dp))
                        Text(locLine, color = SevaInk500, fontSize = 12.sp)
                    }
                    Spacer(Modifier.height(8.dp))
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        InlineStars(rating = p.ratingAvg, count = p.totalJobs)
                        Pill(
                            text = if (p.isAvailable) "Available" else "Busy",
                            kind = if (p.isAvailable) PillKind.Success else PillKind.Warn,
                        )
                    }
                }
            }
            Spacer(Modifier.height(16.dp))
            Box(modifier = Modifier.fillMaxWidth().height(1.dp).background(BorderDefault))
            Spacer(Modifier.height(12.dp))
            // 3-stat grid
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Stat(
                    modifier = Modifier.weight(1f),
                    label = "Hourly",
                    value = p.hourlyRate?.let { formatRupees(it) } ?: "—",
                    color = SevaInk900,
                )
                Stat(
                    modifier = Modifier.weight(1f),
                    label = "Jobs done",
                    value = p.totalJobs.toString(),
                    color = SevaInk900,
                )
                Stat(
                    modifier = Modifier.weight(1f),
                    label = "Completion",
                    value = run {
                        val pct = if (p.completionRate <= 1.0) p.completionRate * 100 else p.completionRate
                        "${pct.toInt()}%"
                    },
                    color = SevaGreen700,
                )
            }
        }
        Box(modifier = Modifier.fillMaxWidth().height(1.dp).background(BorderDefault))

        // About
        if (!p.bio.isNullOrBlank()) {
            EsSection(title = "About") {
                Column(modifier = Modifier.padding(horizontal = 16.dp)) {
                    Text(
                        p.bio,
                        color = SevaInk700,
                        fontSize = 13.sp,
                        lineHeight = 19.5.sp,
                    )
                }
            }
        }

        // Specializations — soft (green-50) chips
        if (!p.specializations.isNullOrEmpty()) {
            EsSection(title = "Specializations") {
                Box(modifier = Modifier.padding(horizontal = 16.dp)) {
                    ChipFlowSoft(items = p.specializations.orEmpty())
                }
            }
        }

        // Brands serviced — neutral (paper-2) chips
        if (!p.brandsServiced.isNullOrEmpty()) {
            EsSection(title = "Brands serviced") {
                Box(modifier = Modifier.padding(horizontal = 16.dp)) {
                    ChipFlowNeutral(items = p.brandsServiced.orEmpty())
                }
            }
        }

        // OEM training (only when present)
        if (!p.oemTrainingBadges.isNullOrEmpty()) {
            EsSection(title = "OEM training") {
                Column(
                    modifier = Modifier.padding(horizontal = 16.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    p.oemTrainingBadges.orEmpty().forEach { o ->
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            Icon(
                                Icons.Outlined.Verified,
                                contentDescription = null,
                                tint = SevaGreen700,
                                modifier = Modifier.size(16.dp),
                            )
                            Text(o, color = SevaInk700, fontSize = 13.sp)
                        }
                    }
                }
            }
        }

        // Service area
        if (p.baseLatitude != null && p.baseLongitude != null) {
            EsSection(title = "Service area") {
                Column(modifier = Modifier.padding(horizontal = 16.dp)) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(140.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .background(Paper3),
                    ) {
                        ServiceAreaMap(
                            baseLatitude = p.baseLatitude,
                            baseLongitude = p.baseLongitude,
                            serviceRadiusKm = p.serviceRadiusKm,
                            engineerName = p.fullName,
                            modifier = Modifier.fillMaxSize(),
                        )
                    }
                    Spacer(Modifier.height(8.dp))
                    Text(
                        "Service radius: ${p.serviceRadiusKm ?: "—"} km",
                        color = SevaInk500,
                        fontSize = 12.sp,
                    )
                }
            }
        } else if (!p.serviceAreas.isNullOrEmpty() || !p.city.isNullOrBlank()) {
            EsSection(title = "Service area") {
                Column(modifier = Modifier.padding(horizontal = 16.dp)) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(140.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .background(Paper3),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            "Map preview",
                            color = SevaInk500,
                            fontSize = 12.sp,
                        )
                    }
                    Spacer(Modifier.height(8.dp))
                    Text(
                        "Service radius: ${p.serviceRadiusKm ?: 25} km",
                        color = SevaInk500,
                        fontSize = 12.sp,
                    )
                }
            }
        }

        // Contact section — masked-call + chat for hospitals; privacy
        // disclosure for everyone else (engineer-to-engineer browse).
        // Real phone number is never rendered: calls bridge through
        // EquipSeva's ExoPhone so neither side ever sees the other's MSISDN.
        if (viewerIsHospital) {
            EsSection(title = "Contact") {
                MaskedContactPanel(
                    onCall = onCall,
                    onOpenChat = onOpenChat,
                    // Calls bridge through Exotel only when a repair job
                    // (or chat conversation) ties the two parties — server
                    // rejects with NotParticipant otherwise. Mirror that
                    // gate visually instead of letting the user tap a
                    // primary-green button just to bounce off a snackbar.
                    callEnabled = activeRepairJobId != null,
                    chatEnabled = true,
                    callBusy = callBusy,
                    chatBusy = chatBusy,
                )
            }
            // Soft nudge if hospital has no active job yet — Call is
            // visually disabled above (callEnabled = false). This text
            // explains *why* before they wonder.
            if (activeRepairJobId == null) {
                Box(
                    modifier = Modifier
                        .padding(horizontal = 16.dp, vertical = 4.dp)
                        .fillMaxWidth(),
                ) {
                    Text(
                        text = "Book a job or open chat first — calls are scoped to active jobs.",
                        color = SevaInk500,
                        fontSize = 12.sp,
                    )
                }
            }
        } else if (hasRelationship) {
            // Engineer-to-engineer (or other-role) browse with relationship.
            // Skip the masked-call panel; just nudge to chat from the
            // sticky CTA bar above. Keep a privacy footer for parity.
            Box(
                modifier = Modifier
                    .padding(16.dp)
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(SevaInfo50)
                    .padding(12.dp),
            ) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.Top,
                ) {
                    Icon(
                        Icons.Outlined.Security,
                        contentDescription = null,
                        tint = SevaInfo500,
                        modifier = Modifier
                            .padding(top = 1.dp)
                            .size(16.dp),
                    )
                    Text(
                        "Use Message above — direct calls are scoped to hospital ↔ engineer job pairs.",
                        color = SevaInfo500,
                        fontSize = 12.sp,
                        lineHeight = 17.sp,
                    )
                }
            }
        } else {
            Box(
                modifier = Modifier
                    .padding(16.dp)
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(SevaInfo50)
                    .padding(12.dp),
            ) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.Top,
                ) {
                    Icon(
                        Icons.Outlined.Security,
                        contentDescription = null,
                        tint = SevaInfo500,
                        modifier = Modifier
                            .padding(top = 1.dp)
                            .size(16.dp),
                    )
                    Text(
                        "Real numbers stay private. Use Message above to start a conversation.",
                        color = SevaInfo500,
                        fontSize = 12.sp,
                        lineHeight = 17.sp,
                    )
                }
            }
        }

        Spacer(Modifier.height(16.dp))

        ReviewsSection(
            reviews = reviews,
            loading = reviewsLoading,
            categorySummary = categorySummary,
        )

        // PR-B: repeat-booking nudge — only renders if alternatives are
        // present. Sits above the sticky CTA so a hospital scrolling to
        // tap "Request this engineer" sees it on the way down.
        if (nudgeAlternatives.isNotEmpty() && nudgeDistanceKm != null) {
            Spacer(Modifier.height(12.dp))
            RepeatBookingNudge(
                engineerName = p.fullName,
                distanceKm = nudgeDistanceKm,
                alternatives = nudgeAlternatives,
                onPickAlternative = onPickAlternative,
                onDismiss = onDismissNudge,
            )
        }

        Spacer(Modifier.height(16.dp))
    }
}

@Composable
private fun ReviewsSection(
    reviews: List<EngineerDirectoryRepository.EngineerReview>,
    loading: Boolean,
    categorySummary: List<EngineerDirectoryRepository.CategoryReviewSummary>,
) {
    // Header is always rendered so the layout doesn't jump when reviews
    // arrive a moment later than the profile body. Empty + loading both
    // collapse to a one-liner.
    EsSection(title = "Recent reviews") {
        // PR-B: per-category aggregate pills rendered above the review
        // list. One pill per category with non-zero reviews. Hidden
        // when the RPC has nothing to render.
        if (categorySummary.isNotEmpty()) {
            Row(
                modifier = Modifier
                    .padding(horizontal = 16.dp, vertical = 4.dp)
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                categorySummary.forEach { sum ->
                    EsChip(
                        text = "${prettyKey(sum.equipmentCategory)} · ${sum.reviewCount} · ${"%.1f".format(java.util.Locale.US, sum.ratingAvg)}★",
                        active = false,
                    )
                }
            }
            Spacer(Modifier.height(4.dp))
        }
        when {
            loading && reviews.isEmpty() -> Text(
                text = "Loading reviews…",
                color = SevaInk500,
                fontSize = 12.sp,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
            )
            reviews.isEmpty() -> Text(
                text = "No reviews yet — be the first to leave one after a completed job.",
                color = SevaInk500,
                fontSize = 12.sp,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
            )
            else -> Column(
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                reviews.forEach { r -> ReviewItem(r) }
            }
        }
    }
}

@Composable
private fun ReviewItem(r: EngineerDirectoryRepository.EngineerReview) {
    val whenLabel: String = remember(r.completedAtIso) {
        com.equipseva.app.core.util.relativeLabel(r.completedAtIso).orEmpty()
    }
    val cityLabel = r.hospitalCity?.takeIf { it.isNotBlank() }?.let { " · $it" }.orEmpty()
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(10.dp))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            InlineStars(rating = r.rating.toDouble(), count = 0, small = false)
            // count=0 reads as a redundant "(0)" — strip it via a thin
            // wrapper that hides the count chip when 0. Falls back to the
            // shared component for the star + number.
            Text(
                text = whenLabel + cityLabel,
                color = SevaInk500,
                fontSize = 11.sp,
            )
        }
        // PR-B: tiny category chip when the review has an associated
        // equipment category. Hidden if the field is null/blank.
        r.equipmentCategory?.takeIf { it.isNotBlank() }?.let { cat ->
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(4.dp))
                    .background(Paper2)
                    .padding(horizontal = 6.dp, vertical = 2.dp),
            ) {
                Text(prettyKey(cat), color = SevaInk600, fontSize = 10.sp)
            }
        }
        if (r.review.isNotBlank()) {
            Text(
                text = r.review,
                color = SevaInk700,
                fontSize = 13.sp,
                lineHeight = 18.sp,
                maxLines = 6,
                overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis,
            )
        }
    }
}

@Composable
private fun Stat(
    modifier: Modifier = Modifier,
    label: String,
    value: String,
    color: Color,
) {
    Column(modifier = modifier) {
        Text(label, fontSize = 11.sp, color = SevaInk500)
        Spacer(Modifier.height(2.dp))
        Text(
            value,
            fontSize = 15.sp,
            fontWeight = FontWeight.Bold,
            color = color,
        )
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ChipFlowSoft(items: List<String>) {
    FlowRow(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        items.forEach { item ->
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(999.dp))
                    .background(SevaGreen50)
                    .border(1.dp, SevaGreen100, RoundedCornerShape(999.dp))
                    .padding(horizontal = 12.dp, vertical = 6.dp),
            ) {
                Text(prettyKey(item), color = SevaGreen700, fontSize = 12.sp, fontWeight = FontWeight.Medium)
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ChipFlowNeutral(items: List<String>) {
    FlowRow(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        items.forEach { item ->
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(999.dp))
                    .background(Paper2)
                    .padding(horizontal = 12.dp, vertical = 6.dp),
            ) {
                Text(item, color = SevaInk600, fontSize = 12.sp, fontWeight = FontWeight.Medium)
            }
        }
    }
}

/**
 * Great-circle distance between two lat/lng pairs in km. Earth radius
 * 6371 km. Pure helper — extracted top-level so the
 * EngineerPublicProfileScreen / RepeatBookingNudge distance gate can
 * be unit-tested without standing up the surrounding VM.
 */
internal fun haversineKm(
    lat1: Double, lng1: Double, lat2: Double, lng2: Double,
): Double {
    val r = 6371.0
    val dLat = Math.toRadians(lat2 - lat1)
    val dLng = Math.toRadians(lng2 - lng1)
    val a = kotlin.math.sin(dLat / 2).let { it * it } +
        kotlin.math.cos(Math.toRadians(lat1)) *
        kotlin.math.cos(Math.toRadians(lat2)) *
        kotlin.math.sin(dLng / 2).let { it * it }
    return 2 * r * kotlin.math.asin(kotlin.math.sqrt(a))
}
