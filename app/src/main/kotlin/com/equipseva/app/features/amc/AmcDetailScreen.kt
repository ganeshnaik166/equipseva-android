package com.equipseva.app.features.amc

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Warning
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.runtime.getValue
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
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.core.util.isWithinDays
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.amc.AmcRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.data.prefs.UserPrefs
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsChip
import com.equipseva.app.designsystem.components.EsSection
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.Paper2
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaDanger50
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk400
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.designsystem.theme.SevaWarning500
import com.equipseva.app.features.auth.UserRole
import com.equipseva.app.navigation.Routes
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class AmcDetailViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val repo: AmcRepository,
    private val auth: AuthRepository,
    private val userPrefs: UserPrefs,
    private val chatRepository: com.equipseva.app.core.data.chat.ChatRepository,
) : ViewModel() {

    private val contractId: String =
        savedStateHandle[Routes.AMC_CONTRACT_DETAIL_ARG_ID] ?: ""

    enum class Tab { Overview, Pool, Visits, Sla, Rotation }

    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val tab: Tab = Tab.Overview,
        val role: UserRole? = null,
        val viewerIsHospital: Boolean = false,
        val hospital: AmcRepository.HospitalContract? = null,
        val engineerView: AmcRepository.EngineerContract? = null,
        val poolBalance: Double? = null,
        val poolLedger: List<AmcRepository.PoolLedgerRow> = emptyList(),
        val visits: List<AmcRepository.AmcVisitRow> = emptyList(),
        val rotation: List<AmcRepository.AmcRotationRow> = emptyList(),
        val breaches: List<AmcRepository.AmcSlaBreach> = emptyList(),
        val cancelling: Boolean = false,
        val cancelConfirmOpen: Boolean = false,
        val topUpOpen: Boolean = false,
        val topUpMonths: Int = 1,
        val topUpBusy: Boolean = false,
        // Round 420 — AMC auto-charge (phase 4). subscription is the most-
        // recent row from get_amc_subscription_for_contract; null when the
        // hospital hasn't set up auto-pay or RLS hides it. autoPayBusy
        // covers both the setup-request and cancel paths.
        val subscription: AmcRepository.SubscriptionRow? = null,
        val autoPayBusy: Boolean = false,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { refresh() }

    fun selectTab(t: Tab) = _state.update { it.copy(tab = t) }

    fun refresh() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            // Fail fast on malformed deep-links (`/amc/contract/<garbage>`
            // landed here with contractId = "" before) — otherwise the
            // screen renders a blank "no contract" view with no signal
            // to the user that the route was bad.
            if (contractId.isBlank()) {
                _state.update {
                    it.copy(loading = false, error = "Couldn't open that contract — the link looks invalid.")
                }
                return@launch
            }
            val session = auth.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .firstOrNull()
            if (session == null) {
                _state.update { it.copy(loading = false, error = "Sign in to view contracts.") }
                return@launch
            }
            val role = runCatching { userPrefs.activeRole.first() }.getOrNull()
                ?.let { UserRole.fromKey(it) }
            val isHospital = role == UserRole.HOSPITAL

            // Fan-out best-effort fetches; any single failure leaves the
            // screen partially populated rather than blank.
            if (isHospital) {
                repo.listForHospital()
                    .onSuccess { rows ->
                        val match = rows.firstOrNull { it.id == contractId }
                        _state.update { it.copy(hospital = match) }
                    }
            } else {
                repo.listForEngineer()
                    .onSuccess { rows ->
                        val match = rows.firstOrNull { it.id == contractId }
                        _state.update { it.copy(engineerView = match) }
                    }
            }

            repo.getPoolBalance(contractId)
                .onSuccess { v -> _state.update { it.copy(poolBalance = v) } }
            repo.listPoolLedger(contractId)
                .onSuccess { v -> _state.update { it.copy(poolLedger = v) } }
            repo.listVisits(contractId)
                .onSuccess { v -> _state.update { it.copy(visits = v) } }
            repo.listRotation(contractId)
                .onSuccess { v -> _state.update { it.copy(rotation = v) } }
            repo.listSlaBreaches(contractId)
                .onSuccess { v -> _state.update { it.copy(breaches = v) } }
            // Round 420 — auto-pay subscription state. Read-only here; the
            // Setup / Cancel CTAs are wired through their own viewmodel
            // methods. Null is OK (hospital hasn't enrolled).
            repo.fetchSubscription(contractId)
                .onSuccess { v -> _state.update { it.copy(subscription = v) } }

            _state.update {
                it.copy(loading = false, role = role, viewerIsHospital = isHospital)
            }
        }
    }

    fun openCancelConfirm() {
        if (_state.value.cancelling) return
        _state.update { it.copy(cancelConfirmOpen = true) }
    }

    fun dismissCancelConfirm() {
        if (_state.value.cancelling) return
        _state.update { it.copy(cancelConfirmOpen = false) }
    }

    fun cancel() {
        if (_state.value.cancelling) return
        _state.update { it.copy(cancelling = true, cancelConfirmOpen = false) }
        viewModelScope.launch {
            repo.cancelContract(contractId, reason = null)
                .onSuccess {
                    _state.update { it.copy(cancelling = false) }
                    refresh()
                }
                .onFailure { e ->
                    _state.update { it.copy(cancelling = false, error = e.toUserMessage()) }
                }
        }
    }

    // Round 420 — request auto-pay setup. The actual Razorpay mandate
    // authorization will fire from a follow-up edge fn (phase 5); for
    // now the RPC just inserts the pending row. The UI shows a "Pending
    // mandate" state until the edge fn wires in.
    private val _autoPayMessage =
        kotlinx.coroutines.flow.MutableSharedFlow<String>(extraBufferCapacity = 2)
    val autoPayMessage: kotlinx.coroutines.flow.Flow<String> = _autoPayMessage

    fun setupAutoPay() {
        if (_state.value.autoPayBusy) return
        _state.update { it.copy(autoPayBusy = true) }
        viewModelScope.launch {
            repo.requestSubscriptionSetup(contractId)
                .onSuccess {
                    _autoPayMessage.tryEmit(
                        "Auto-pay setup requested. You'll receive a payment-authorization link shortly."
                    )
                    _state.update { it.copy(autoPayBusy = false) }
                    refresh()
                }
                .onFailure { e ->
                    _state.update { it.copy(autoPayBusy = false, error = e.toUserMessage()) }
                }
        }
    }

    fun cancelAutoPay() {
        val sub = _state.value.subscription ?: return
        if (_state.value.autoPayBusy) return
        _state.update { it.copy(autoPayBusy = true) }
        viewModelScope.launch {
            repo.cancelSubscription(sub.id)
                .onSuccess {
                    _autoPayMessage.tryEmit("Auto-pay cancelled.")
                    _state.update { it.copy(autoPayBusy = false) }
                    refresh()
                }
                .onFailure { e ->
                    _state.update { it.copy(autoPayBusy = false, error = e.toUserMessage()) }
                }
        }
    }

    fun openTopUp() = _state.update { it.copy(topUpOpen = true, topUpMonths = 1) }
    fun dismissTopUp() = _state.update { it.copy(topUpOpen = false) }
    // Server accepts top-ups in 1..36 months (per AmcRepository). The
    // earlier client clamp at 12 silently capped hospitals trying to
    // pre-fund a 2- or 3-year contract.
    fun setTopUpMonths(m: Int) = _state.update { it.copy(topUpMonths = m.coerceIn(1, 36)) }
    fun markTopUpBusy(busy: Boolean) = _state.update { it.copy(topUpBusy = busy) }

    fun removeFallback(engineerId: String) {
        viewModelScope.launch {
            repo.removeFallbackEngineer(contractId, engineerId)
                .onSuccess { refresh() }
                .onFailure { e -> _state.update { it.copy(error = e.toUserMessage()) } }
        }
    }

    fun contractIdValue(): String = contractId

    // Round 327 — engineer-side "Message hospital" entry point. The
    // round-326 amc_renewal_due notification routes both parties to
    // this detail screen; hospitals see Renew CTA, engineers had
    // nothing actionable. Resolves the conversation via getOrCreateDirect
    // and emits the new id so the screen navigates into chat.
    private val _openConversation =
        kotlinx.coroutines.flow.MutableSharedFlow<String>(extraBufferCapacity = 1)
    val openConversation: kotlinx.coroutines.flow.Flow<String> = _openConversation

    fun messageHospital() {
        val peer = _state.value.engineerView?.hospitalUserId ?: return
        viewModelScope.launch {
            val session = auth.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .firstOrNull() ?: return@launch
            chatRepository.getOrCreateDirect(session.userId, peer)
                .onSuccess { conv -> _openConversation.tryEmit(conv.id) }
                .onFailure { e -> _state.update { it.copy(error = e.toUserMessage()) } }
        }
    }
}

@Composable
fun AmcDetailScreen(
    onBack: () -> Unit,
    onShowMessage: (String) -> Unit,
    onRenew: (engineerId: String, sourceContractId: String) -> Unit = { _, _ -> },
    onOpenConversation: (conversationId: String) -> Unit = {},
    viewModel: AmcDetailViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    // Round 327 — collect the conversation-id effect so engineer can
    // be routed into chat after messageHospital() resolves.
    androidx.compose.runtime.LaunchedEffect(viewModel) {
        viewModel.openConversation.collect { conversationId ->
            onOpenConversation(conversationId)
        }
    }
    // Round 420 — surface auto-pay setup / cancel outcome to the user.
    androidx.compose.runtime.LaunchedEffect(viewModel) {
        viewModel.autoPayMessage.collect { msg -> onShowMessage(msg) }
    }
    // Round 428 — re-fetch on return so visits / pool balance / SLA
    // breaches / subscription state landed while user was in chat
    // or picker surface refresh. The viewmodel only runs refresh()
    // once via init {}; without this hook, a top-up that completed
    // during a chat hop wouldn't appear in the Pool tab.
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.refresh() }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "AMC contract", onBack = onBack)
            Box(modifier = Modifier.weight(1f)) {
                when {
                    state.loading -> Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center,
                    ) { CircularProgressIndicator() }

                    state.hospital == null && state.engineerView == null ->
                        Text(
                            state.error ?: "Contract not found.",
                            color = SevaInk500,
                            fontSize = 13.sp,
                            modifier = Modifier.padding(16.dp),
                        )

                    else -> Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .verticalScroll(rememberScrollState()),
                    ) {
                        // Drive paused-banner from server-side status, not
                        // local balance compare. Backend pauses when pool
                        // hits 0 OR the contract is suspended; the earlier
                        // `balance < 0` check missed both "depleted-not-
                        // overdrawn" (exactly 0) and admin-paused contracts.
                        val pausedByServer = state.hospital?.status == "paused" ||
                            state.engineerView?.status == "paused"
                        if (pausedByServer || (state.poolBalance ?: 0.0) <= 0.0) {
                            PausedBanner()
                        }
                        TabsRow(
                            selected = state.tab,
                            onSelect = viewModel::selectTab,
                        )
                        when (state.tab) {
                            AmcDetailViewModel.Tab.Overview ->
                                OverviewTab(
                                    state = state,
                                    onRenew = onRenew,
                                    onMessageHospital = viewModel::messageHospital,
                                )
                            AmcDetailViewModel.Tab.Pool -> PoolTab(
                                state = state,
                                onTopUp = { viewModel.openTopUp() },
                                onSetupAutoPay = viewModel::setupAutoPay,
                                onCancelAutoPay = viewModel::cancelAutoPay,
                            )
                            AmcDetailViewModel.Tab.Visits -> VisitsTab(state)
                            AmcDetailViewModel.Tab.Sla -> SlaTab(state)
                            AmcDetailViewModel.Tab.Rotation -> RotationTab(
                                state = state,
                                onRemove = viewModel::removeFallback,
                            )
                        }
                        Spacer(Modifier.height(24.dp))
                    }
                }
            }
            // Sticky bottom CTAs — hospital only. Engineer view is read-only.
            if (state.viewerIsHospital && state.hospital != null) {
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
                                text = if (state.cancelling) "Cancelling…" else "Cancel",
                                // Open confirmation dialog instead of
                                // firing the RPC straight away. Cancelling
                                // an AMC is irreversible — releases the
                                // engineer rotation slot, refunds remaining
                                // months — so a single mis-tap should not
                                // be enough.
                                onClick = { viewModel.openCancelConfirm() },
                                kind = EsBtnKind.DangerOutline,
                                size = EsBtnSize.Lg,
                                disabled = state.cancelling ||
                                    state.hospital?.status in CANCELLED_STATES,
                            )
                            Box(modifier = Modifier.weight(1f)) {
                                EsBtn(
                                    text = "Add months",
                                    onClick = { viewModel.openTopUp() },
                                    kind = EsBtnKind.Primary,
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

    if (state.cancelConfirmOpen) {
        androidx.compose.material3.AlertDialog(
            onDismissRequest = { viewModel.dismissCancelConfirm() },
            title = { Text("Cancel this contract?") },
            text = {
                Text(
                    // Earlier copy promised a "wallet refund" — there is no
                    // in-app wallet feature; the backend cancel_amc_contract
                    // RPC doesn't process refunds either. Describe what
                    // cancel actually does: stops the contract, halts
                    // engineer notifications. Refund-of-pool handling is
                    // out-of-band per terms; surface that fact instead of
                    // promising a flow we don't ship.
                    "Cancelling ends the maintenance contract. Assigned " +
                        "engineers stop receiving visit notifications. " +
                        "Any unused pool balance is settled per the contract " +
                        "terms — our team will reach out within 7 business " +
                        "days. This can't be undone.",
                )
            },
            confirmButton = {
                androidx.compose.material3.TextButton(
                    onClick = { viewModel.cancel() },
                    enabled = !state.cancelling,
                ) {
                    Text(
                        if (state.cancelling) "Cancelling…" else "Cancel contract",
                        color = SevaDanger500,
                    )
                }
            },
            dismissButton = {
                androidx.compose.material3.TextButton(
                    onClick = { viewModel.dismissCancelConfirm() },
                    enabled = !state.cancelling,
                ) { Text("Keep contract") }
            },
        )
    }

    if (state.topUpOpen && state.hospital != null) {
        AmcPaymentSheet(
            contractId = viewModel.contractIdValue(),
            monthlyFeeRupees = state.hospital!!.monthlyFeeRupees,
            initialMonths = state.topUpMonths,
            onMonthsChange = viewModel::setTopUpMonths,
            onClose = { viewModel.dismissTopUp() },
            onShowMessage = onShowMessage,
            onCompleted = {
                viewModel.dismissTopUp()
                viewModel.refresh()
            },
            engineerName = state.hospital!!.primaryEngineerName.takeIf { it.isNotBlank() }
                ?: "your engineer",
        )
    }
}

private val CANCELLED_STATES = setOf("cancelled", "expired", "renewal_failed")

@Composable
private fun PausedBanner() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(SevaDanger50)
            .padding(12.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Icon(
                imageVector = Icons.Outlined.Warning,
                contentDescription = null,
                tint = SevaDanger500,
                modifier = Modifier.width(18.dp),
            )
            Text(
                "Contract paused — top up to resume.",
                color = SevaDanger500,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
            )
        }
    }
}

@Composable
private fun TabsRow(
    selected: AmcDetailViewModel.Tab,
    onSelect: (AmcDetailViewModel.Tab) -> Unit,
) {
    val items = listOf(
        AmcDetailViewModel.Tab.Overview to "Overview",
        AmcDetailViewModel.Tab.Pool to "Pool",
        AmcDetailViewModel.Tab.Visits to "Visits",
        AmcDetailViewModel.Tab.Sla to "SLA",
        AmcDetailViewModel.Tab.Rotation to "Rotation",
    )
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        items.forEach { (tab, label) ->
            EsChip(
                text = label,
                active = selected == tab,
                onClick = { onSelect(tab) },
            )
        }
    }
}

@Composable
private fun OverviewTab(
    state: AmcDetailViewModel.UiState,
    onRenew: (engineerId: String, sourceContractId: String) -> Unit = { _, _ -> },
    onMessageHospital: () -> Unit = {},
) {
    val title = state.hospital?.primaryEngineerName ?: state.engineerView?.hospitalName ?: "—"
    val status = state.hospital?.status ?: state.engineerView?.status ?: "active"
    val freq = state.hospital?.visitFrequency ?: state.engineerView?.visitFrequency ?: ""
    val fee = state.hospital?.monthlyFeeRupees ?: state.engineerView?.monthlyFeeRupees ?: 0.0
    val visitsDone = state.hospital?.visitsCompleted ?: state.engineerView?.visitsCompleted ?: 0
    val visitsPerYr = state.hospital?.visitsPerYear ?: state.engineerView?.visitsPerYear ?: 12
    val start = state.hospital?.startDate ?: state.engineerView?.startDate ?: ""
    val end = state.hospital?.endDate ?: state.engineerView?.endDate ?: ""
    val nextVisit = state.hospital?.nextVisitAt ?: state.engineerView?.nextVisitAt
    val scope = state.hospital?.scopeText ?: state.engineerView?.scopeText
    val cats = state.hospital?.equipmentCategories ?: state.engineerView?.equipmentCategories
        ?: emptyList()
    val autoRenew = state.hospital?.autoRenew ?: false
    Column {
        EsSection(title = "Overview") {
            Column(
                modifier = Modifier.padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Text(title, color = SevaInk900, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                    StatusPillFor(status)
                }
                if (state.engineerView != null && !state.viewerIsHospital) {
                    Pill(
                        text = if (state.engineerView.isPrimary) "Primary engineer" else "Fallback engineer",
                        kind = PillKind.Default,
                    )
                }
                LabelRow("Frequency", prettyFrequency(freq))
                LabelRow("Monthly fee", formatRupees(fee))
                LabelRow("Visits", "$visitsDone / $visitsPerYr per year")
                LabelRow("Term", "${prettyDate(start)} → ${prettyDate(end)}")
                if (!nextVisit.isNullOrBlank()) {
                    LabelRow("Next visit", prettyDate(nextVisit))
                }
                if (autoRenew) {
                    Pill(text = "Auto-renew", kind = PillKind.Default)
                }

                // Round 314 — surface the Renew CTA when end_date is within
                // 30 days and the contract is still active. The server-side
                // notify_expiring_amc_contracts (round 313) pages the
                // hospital at 7 days; this CTA gives them a button when
                // they actually land on the detail screen so they don't
                // have to bounce back to the engineer profile.
                // Round 354 — threshold widened 14d → 30d to align with the
                // round-352 founder dashboard "Expiring 30d" KPI + the
                // round-353 hospital list countdown pill. Surfaces stay in
                // lock-step on the renewal window.
                val engineerIdForRenew = state.hospital?.primaryEngineerId
                val sourceIdForRenew = state.hospital?.id
                if (state.viewerIsHospital
                    && status == "active"
                    && !engineerIdForRenew.isNullOrBlank()
                    && !sourceIdForRenew.isNullOrBlank()
                    && isWithinDays(end, 30)
                ) {
                    Spacer(Modifier.height(4.dp))
                    EsBtn(
                        text = "Renew contract",
                        kind = EsBtnKind.Primary,
                        size = EsBtnSize.Md,
                        full = true,
                        onClick = { onRenew(engineerIdForRenew, sourceIdForRenew) },
                    )
                }

                // Round 327 — engineer-side action when the AMC is
                // approaching expiry. Hospital sees Renew; engineer
                // sees "Message hospital" so they can prompt the
                // renewal conversation. Round 354 — same 30d threshold.
                if (!state.viewerIsHospital
                    && status == "active"
                    && state.engineerView != null
                    && isWithinDays(end, 30)
                ) {
                    Spacer(Modifier.height(4.dp))
                    EsBtn(
                        text = "Message hospital",
                        kind = EsBtnKind.Primary,
                        size = EsBtnSize.Md,
                        full = true,
                        onClick = onMessageHospital,
                    )
                }
            }
        }
        if (cats.isNotEmpty()) {
            EsSection(title = "Equipment categories") {
                CategoryFlow(items = cats)
            }
        }
        if (!scope.isNullOrBlank()) {
            EsSection(title = "Scope") {
                Text(
                    text = scope,
                    color = SevaInk700,
                    fontSize = 13.sp,
                    modifier = Modifier.padding(horizontal = 16.dp),
                )
            }
        }
    }
}

@Composable
private fun PoolTab(
    state: AmcDetailViewModel.UiState,
    onTopUp: () -> Unit,
    onSetupAutoPay: () -> Unit,
    onCancelAutoPay: () -> Unit,
) {
    EsSection(title = "Pool balance") {
        Column(
            modifier = Modifier.padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            val balance = state.poolBalance ?: 0.0
            val balanceColor = if (balance < 0) SevaDanger500 else SevaGreen700
            Text(
                formatRupees(balance),
                color = balanceColor,
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
            )
            Text(
                "Pre-paid balance held in escrow. Each completed visit deducts the per-visit fair share automatically.",
                color = SevaInk500,
                fontSize = 12.sp,
            )
            if (state.viewerIsHospital) {
                Spacer(Modifier.height(4.dp))
                EsBtn(
                    text = "Top up",
                    onClick = onTopUp,
                    kind = EsBtnKind.Primary,
                )
            }
        }
    }
    // Round 420 — auto-pay enrolment block. Hospital-only; the back-end
    // RPC enforces this too. Show one of: cold-state with Setup CTA,
    // pending-mandate state, active state with mandate summary + cancel,
    // or halted/cancelled state with a re-enrol CTA.
    if (state.viewerIsHospital) {
        AutoPaySection(
            state = state,
            onSetup = onSetupAutoPay,
            onCancel = onCancelAutoPay,
        )
    }
    EsSection(title = "Recent activity") {
        if (state.poolLedger.isEmpty()) {
            Text(
                "Ledger entries appear here once visits complete or top-ups land.",
                color = SevaInk500,
                fontSize = 12.sp,
                modifier = Modifier.padding(horizontal = 16.dp),
            )
        } else {
            Column(
                modifier = Modifier.padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                state.poolLedger.forEach { row -> PoolLedgerRow(row) }
            }
        }
    }
}

// Round 420 — auto-pay enrolment section. Reads state.subscription and
// renders one of four flavors based on status. Setup is the cold-state
// CTA; Cancel appears while a subscription is live; halted/cancelled
// surfaces a re-enrol affordance. The actual Razorpay mandate-link
// flow lands in a follow-up phase — for now Setup just persists the
// pending row + raises a "we'll send a link" toast.
@Composable
private fun AutoPaySection(
    state: AmcDetailViewModel.UiState,
    onSetup: () -> Unit,
    onCancel: () -> Unit,
) {
    val sub = state.subscription
    val title = "Auto-pay"
    EsSection(title = title) {
        Column(
            modifier = Modifier.padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            when (val status = sub?.status) {
                null -> {
                    // Cold state — never enrolled.
                    Text(
                        "Pay your monthly fee automatically. We'll send a payment-authorization link for your bank or UPI app, then debit each month with no further action needed.",
                        color = SevaInk500,
                        fontSize = 12.sp,
                    )
                    EsBtn(
                        text = if (state.autoPayBusy) "Requesting…" else "Set up auto-pay",
                        onClick = onSetup,
                        kind = EsBtnKind.Primary,
                        disabled = state.autoPayBusy,
                    )
                }
                "pending", "authenticated" -> {
                    Pill(text = "Pending authorization", kind = PillKind.Warn)
                    Text(
                        "We've started setting up auto-pay. Once you authorize the mandate, monthly debits will resume here.",
                        color = SevaInk500,
                        fontSize = 12.sp,
                    )
                    EsBtn(
                        text = if (state.autoPayBusy) "Cancelling…" else "Cancel auto-pay",
                        onClick = onCancel,
                        kind = EsBtnKind.Secondary,
                        disabled = state.autoPayBusy,
                    )
                }
                "active" -> {
                    Pill(text = "Active", kind = PillKind.Success)
                    sub.mandateSummary?.takeIf { it.isNotBlank() }?.let { summary ->
                        Text("Paying via $summary", color = SevaInk700, fontSize = 13.sp)
                    }
                    sub.nextChargeAt?.let { next ->
                        Text(
                            "Next debit: ${prettyDate(next)}",
                            color = SevaInk500,
                            fontSize = 12.sp,
                        )
                    }
                    if (sub.totalChargesSucceeded > 0) {
                        Text(
                            "${sub.totalChargesSucceeded} successful debits to date",
                            color = SevaInk500,
                            fontSize = 12.sp,
                        )
                    }
                    EsBtn(
                        text = if (state.autoPayBusy) "Cancelling…" else "Cancel auto-pay",
                        onClick = onCancel,
                        kind = EsBtnKind.Secondary,
                        disabled = state.autoPayBusy,
                    )
                }
                "paused" -> {
                    Pill(text = "Paused", kind = PillKind.Warn)
                    Text(
                        "Auto-pay is paused — usually because of insufficient balance on your linked instrument. We retry automatically.",
                        color = SevaInk500,
                        fontSize = 12.sp,
                    )
                    EsBtn(
                        text = if (state.autoPayBusy) "Cancelling…" else "Cancel auto-pay",
                        onClick = onCancel,
                        kind = EsBtnKind.Secondary,
                        disabled = state.autoPayBusy,
                    )
                }
                "halted", "cancelled", "completed", "expired" -> {
                    val pillText = when (status) {
                        "halted" -> "Halted"
                        "cancelled" -> "Cancelled"
                        "completed" -> "Completed"
                        else -> "Expired"
                    }
                    Pill(text = pillText, kind = PillKind.Default)
                    sub.lastFailureReason?.takeIf { it.isNotBlank() }?.let { reason ->
                        Text(
                            "Last issue: $reason",
                            color = SevaInk500,
                            fontSize = 12.sp,
                        )
                    }
                    EsBtn(
                        text = if (state.autoPayBusy) "Requesting…" else "Set up auto-pay again",
                        onClick = onSetup,
                        kind = EsBtnKind.Primary,
                        disabled = state.autoPayBusy,
                    )
                }
                else -> {
                    // Unknown status — render the raw value defensively
                    // so ops see something rather than a blank section.
                    Pill(text = status.replaceFirstChar { it.uppercase() }, kind = PillKind.Default)
                }
            }
        }
    }
}

@Composable
private fun PoolLedgerRow(row: AmcRepository.PoolLedgerRow) {
    val isCredit = isPoolLedgerCredit(row.ledgerKind)
    val sign = if (isCredit) "+" else "−"
    val color = if (isCredit) SevaGreen700 else SevaDanger500
    val label = poolLedgerLabel(row.ledgerKind, row.sourceBreachId)
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(label, color = SevaInk900, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
            row.description?.takeIf { it.isNotBlank() }?.let {
                Text(it, color = SevaInk500, fontSize = 11.sp)
            }
            row.createdAtIso?.let {
                Text(prettyDate(it), color = SevaInk400, fontSize = 11.sp)
            }
        }
        Column(horizontalAlignment = Alignment.End) {
            Text(
                "$sign${formatRupees(row.amountRupees)}",
                color = color,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                "Bal ${formatRupees(row.balanceAfter)}",
                color = SevaInk500,
                fontSize = 11.sp,
            )
        }
    }
}

@Composable
private fun VisitsTab(state: AmcDetailViewModel.UiState) {
    val visitsDone = state.hospital?.visitsCompleted ?: state.engineerView?.visitsCompleted ?: 0
    val visitsPerYr = state.hospital?.visitsPerYear ?: state.engineerView?.visitsPerYear ?: 12
    val freq = state.hospital?.visitFrequency ?: state.engineerView?.visitFrequency ?: ""
    val nextVisit = state.hospital?.nextVisitAt ?: state.engineerView?.nextVisitAt
    EsSection(title = "Cadence") {
        Column(
            modifier = Modifier.padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            LabelRow("Frequency", prettyFrequency(freq))
            LabelRow("Completed", "$visitsDone / $visitsPerYr")
            if (!nextVisit.isNullOrBlank()) {
                LabelRow("Next scheduled", prettyDate(nextVisit))
            }
        }
    }
    EsSection(title = "Visit history") {
        if (state.visits.isEmpty()) {
            // The previous "runs daily at 09:00 IST" leaked the cron
            // implementation — hospitals don't need to know our scheduler
            // cadence and the time leaks our timezone assumptions
            // anyway. Honest user-facing copy: visits land here once the
            // first scheduled date rolls around.
            Text(
                "No visits yet. Scheduled visits appear here as the engineer logs them.",
                color = SevaInk500,
                fontSize = 12.sp,
                modifier = Modifier.padding(horizontal = 16.dp),
            )
        } else {
            Column(
                modifier = Modifier.padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                state.visits.forEach { v -> VisitRow(v) }
            }
        }
    }
}

@Composable
private fun VisitRow(v: AmcRepository.AmcVisitRow) {
    val statusColor = when (v.status) {
        "completed" -> SevaGreen700
        "cancelled" -> SevaInk500
        else -> SevaWarning500
    }
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                amcVisitHeaderLine(v.amcVisitNumber, v.jobNumber),
                color = SevaInk900,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
            )
            v.engineerName?.let {
                Text(it, color = SevaInk500, fontSize = 11.sp)
            }
            v.scheduledDate?.let {
                Text(prettyDate(it), color = SevaInk400, fontSize = 11.sp)
            }
        }
        Text(
            v.status.replaceFirstChar { it.uppercase() },
            color = statusColor,
            fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold,
        )
    }
}

@Composable
private fun SlaTab(state: AmcDetailViewModel.UiState) {
    EsSection(title = "SLA breaches") {
        if (state.breaches.isEmpty()) {
            Text(
                "No breaches recorded — every visit met its response window so far.",
                color = SevaInk500,
                fontSize = 13.sp,
                modifier = Modifier.padding(horizontal = 16.dp),
            )
        } else {
            Column(
                modifier = Modifier.padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                state.breaches.forEach { b -> SlaBreachCard(b) }
            }
        }
    }
}

@Composable
private fun SlaBreachCard(b: AmcRepository.AmcSlaBreach) {
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
            Pill(
                text = if (b.severity == "emergency") "Emergency" else "Standard",
                kind = if (b.severity == "emergency") PillKind.Danger else PillKind.Warn,
            )
            val typeLabel = when (b.breachType) {
                "response_time" -> "Response time"
                "no_show" -> "No-show"
                "quality" -> "Quality"
                else -> b.breachType
            }
            Text(typeLabel, color = SevaInk900, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
        }
        if (!b.visitCode.isNullOrBlank()) {
            Text("Visit ${b.visitCode}", color = SevaInk500, fontSize = 12.sp)
        }
        Text(
            "Expected within ${b.expectedWithinHours}h" +
                (b.actualHours?.let { " · actual ${"%.1f".format(java.util.Locale.US, it)}h" } ?: ""),
            color = SevaInk700,
            fontSize = 12.sp,
        )
        if (b.creditIssuedRupees > 0) {
            Pill(
                text = "Credit ${formatRupees(b.creditIssuedRupees)}",
                kind = PillKind.Lime,
            )
        }
        Text(
            "Recorded ${prettyDate(b.detectedAt)}",
            color = SevaInk500,
            fontSize = 11.sp,
        )
    }
}

@Composable
private fun RotationTab(
    state: AmcDetailViewModel.UiState,
    onRemove: (engineerId: String) -> Unit,
) {
    EsSection(title = "Engineer rotation") {
        if (state.rotation.isEmpty()) {
            // The previous "Rotation will appear here." was placeholder
            // copy that didn't tell hospitals what they were looking at
            // or how to populate it. Concrete description of how rotation
            // works + the canonical add-fallback path.
            Text(
                if (state.viewerIsHospital)
                    "The primary engineer takes visits first. If they're unavailable, the next priority engineer is dispatched. Add fallbacks from any engineer's profile."
                else
                    "The primary engineer takes visits first. Fallbacks step in when the primary is unavailable.",
                color = SevaInk500,
                fontSize = 13.sp,
                modifier = Modifier.padding(horizontal = 16.dp),
            )
        } else {
            Column(
                modifier = Modifier.padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                state.rotation.forEach { r ->
                    RotationCard(
                        row = r,
                        canRemove = state.viewerIsHospital && !r.isPrimary,
                        onRemove = { onRemove(r.engineerId) },
                    )
                }
                if (state.viewerIsHospital) {
                    Text(
                        "Add fallback engineers from the engineer directory — open a profile and tap 'Set up monthly maintenance'.",
                        color = SevaInk500,
                        fontSize = 12.sp,
                    )
                }
            }
        }
    }
}

@Composable
private fun RotationCard(
    row: AmcRepository.AmcRotationRow,
    canRemove: Boolean,
    onRemove: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(10.dp))
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                row.engineerName,
                color = SevaInk900,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                row.engineerCity?.takeIf { it.isNotBlank() } ?: "—",
                color = SevaInk500,
                fontSize = 12.sp,
            )
        }
        Pill(
            text = if (row.isPrimary) "Primary" else "Priority ${row.priority}",
            kind = if (row.isPrimary) PillKind.Forest else PillKind.Neutral,
        )
        Pill(
            text = if (row.isAvailable) "Available" else "Busy",
            kind = if (row.isAvailable) PillKind.Success else PillKind.Warn,
        )
        if (canRemove) {
            // Round 412 — TalkBack says "Remove" with no context; many
            // engineers on the row → user can't tell which they're about
            // to delete. Include the engineer name in the description so
            // the screen reader announces "Remove Asha Devi" / etc.
            val removeLabel = row.engineerName.takeIf { it.isNotBlank() }
                ?.let { "Remove $it" } ?: "Remove engineer"
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .clickable(onClickLabel = removeLabel) { onRemove() }
                    .padding(8.dp),
            ) {
                Icon(
                    Icons.Outlined.Delete,
                    contentDescription = removeLabel,
                    tint = SevaDanger500,
                )
            }
        }
    }
}

@Composable
private fun LabelRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, color = SevaInk500, fontSize = 12.sp)
        Text(value, color = SevaInk900, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun CategoryFlow(items: List<String>) {
    FlowRow(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        items.forEach { it ->
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(999.dp))
                    .background(Paper2)
                    .padding(horizontal = 12.dp, vertical = 6.dp),
            ) {
                Text(
                    text = amcCategoryLabel(it),
                    color = SevaInk700,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium,
                )
            }
        }
    }
}

/**
 * Header copy for a single AMC visit row: "Visit #N · RPR-NNNN".
 * Falls back to "-" for a missing visit number (legacy rows from
 * before the auto-numbering column landed); job number folds out
 * gracefully so a null / blank jobNumber renders "Visit #3" without
 * the dangling " · " separator. Pre-extraction code used a
 * `.trim()` which only stripped whitespace and left the trailing
 * middle-dot; the helper now drops the separator branch cleanly.
 */
internal fun amcVisitHeaderLine(
    amcVisitNumber: Int?,
    jobNumber: String?,
): String {
    val n = amcVisitNumber?.toString() ?: "-"
    val job = jobNumber?.takeIf { it.isNotBlank() }
    return if (job != null) "Visit #$n · $job" else "Visit #$n"
}

/**
 * True when a pool-ledger entry is a credit (Top-up or Refund). The
 * AMC payment pool nets credits (hospital top-ups / SLA breach
 * refunds) against debits (per-visit fair-share withdrawals); the row
 * card colour-codes accordingly.
 */
internal fun isPoolLedgerCredit(ledgerKind: String): Boolean =
    ledgerKind == "credit" || ledgerKind == "refund"

/**
 * User-facing label for a pool-ledger row. `credit` entries split
 * by source: a credit with a [sourceBreachId] is an automated SLA
 * credit; otherwise it's a hospital top-up. `debit` is always
 * "Visit fair share"; `refund` is "Refund". Unknown wire values fall
 * back to a first-letter-capitalised echo so the row still shows
 * something readable.
 */
internal fun poolLedgerLabel(
    ledgerKind: String,
    sourceBreachId: String?,
): String = when (ledgerKind) {
    "credit" -> if (sourceBreachId != null) "SLA credit" else "Top-up"
    "debit" -> "Visit fair share"
    "refund" -> "Refund"
    else -> ledgerKind.replaceFirstChar { it.uppercase() }
}

