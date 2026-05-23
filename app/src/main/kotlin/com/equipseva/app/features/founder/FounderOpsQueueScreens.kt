package com.equipseva.app.features.founder

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.selection.selectable
import androidx.compose.ui.semantics.Role
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Inbox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
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
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.core.util.prettyDate
import com.equipseva.app.core.util.prettyDateTime
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsBottomSheet
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

// =====================================================================
// 1. Escrow disputes queue
// =====================================================================

@HiltViewModel
class FounderEscrowDisputesViewModel @Inject constructor(
    private val repo: FounderRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        // Round 400 — pull-to-refresh inline indicator.
        val refreshing: Boolean = false,
        val error: String? = null,
        val rows: List<FounderRepository.EscrowDispute> = emptyList(),
        val acting: Set<String> = emptySet(),
        // PR-D32 — sheet keyed by escrowId; null = closed.
        val resolveSheetForEscrowId: String? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload(initial = true) }
    fun onPullToRefresh() = reload(initial = false)

    fun reload(initial: Boolean = false) {
        _state.update {
            it.copy(
                loading = initial || it.rows.isEmpty(),
                refreshing = !initial && it.rows.isNotEmpty(),
                error = null,
            )
        }
        viewModelScope.launch {
            repo.fetchOpenEscrowDisputes()
                .onSuccess { rows -> _state.update { it.copy(loading = false, refreshing = false, rows = rows) } }
                .onFailure { e -> _state.update { it.copy(loading = false, refreshing = false, error = e.toUserMessage()) } }
        }
    }

    fun openResolveSheet(escrowId: String) =
        _state.update { it.copy(resolveSheetForEscrowId = escrowId) }
    fun closeResolveSheet() =
        _state.update { it.copy(resolveSheetForEscrowId = null) }

    fun resolve(escrowId: String, outcome: String, note: String?) {
        if (_state.value.acting.contains(escrowId)) return
        _state.update { it.copy(acting = it.acting + escrowId, error = null) }
        viewModelScope.launch {
            repo.resolveEscrowDispute(escrowId, outcome, note)
                .onSuccess {
                    _state.update {
                        it.copy(
                            acting = it.acting - escrowId,
                            resolveSheetForEscrowId = null,
                            rows = it.rows.filterNot { row -> row.escrowId == escrowId },
                        )
                    }
                }
                .onFailure { e ->
                    _state.update { it.copy(acting = it.acting - escrowId, error = e.toUserMessage()) }
                }
        }
    }
}

@Composable
fun FounderEscrowDisputesScreen(
    onBack: () -> Unit,
    onOpenTimeline: (escrowId: String) -> Unit = {},
    viewModel: FounderEscrowDisputesViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    // Round 429 — refresh on return; admin resolving a dispute pops back
    // to this list and expects the resolved row to drop off immediately.
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }

    // PR-D32 — resolve sheet (note + outcome).
    state.resolveSheetForEscrowId?.let { escrowId ->
        val target = state.rows.firstOrNull { it.escrowId == escrowId }
        AdminResolveDisputeSheet(
            target = target,
            submitting = state.acting.contains(escrowId),
            onDismiss = viewModel::closeResolveSheet,
            onSubmit = { outcome, note -> viewModel.resolve(escrowId, outcome, note) },
        )
    }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(
                title = "Escrow disputes",
                subtitle = simpleQueueCountSubtitle(state.rows.size, "open"),
                onBack = onBack,
            )
            QueueBox(
                loading = state.loading,
                error = state.error,
                empty = state.rows.isEmpty(),
                emptyTitle = "No active disputes",
                emptySubtitle = "Hospitals haven't disputed any held escrows.",
                refreshing = state.refreshing,
                onRefresh = viewModel::onPullToRefresh,
            ) {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(12.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    items(state.rows, key = { it.escrowId }) { row ->
                        EscrowDisputeRow(
                            row = row,
                            onResolve = { viewModel.openResolveSheet(row.escrowId) },
                            onOpenTimeline = { onOpenTimeline(row.escrowId) },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun EscrowDisputeRow(
    row: FounderRepository.EscrowDispute,
    onResolve: () -> Unit,
    onOpenTimeline: () -> Unit,
) {
    QueueCard {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    escrowDisputeRowTitle(row.jobNumber, row.repairJobId),
                    color = SevaInk900,
                    fontWeight = FontWeight.Bold,
                    fontSize = 14.sp,
                )
                Text(
                    escrowDisputeAmountHeldLine(row.amountRupees),
                    color = SevaInk700,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium,
                )
            }
            Pill(text = "Disputed", kind = PillKind.Danger)
        }
        Text(
            escrowDisputePartiesLine(row.hospitalName, row.engineerName),
            color = SevaInk500,
            fontSize = 12.sp,
        )
        if (!row.disputeReason.isNullOrBlank()) {
            Text(row.disputeReason, color = SevaInk700, fontSize = 13.sp)
        }
        if (!row.disputeOpenedAt.isNullOrBlank()) {
            Text("Opened: ${prettyDateTime(row.disputeOpenedAt)}", color = SevaInk500, fontSize = 11.sp)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            EsBtn(
                text = "View timeline",
                kind = EsBtnKind.Secondary,
                size = EsBtnSize.Sm,
                onClick = onOpenTimeline,
                modifier = Modifier.weight(1f),
            )
            EsBtn(
                text = "Resolve",
                kind = EsBtnKind.Primary,
                size = EsBtnSize.Sm,
                onClick = onResolve,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

// =====================================================================
// 2. AMC escalations queue
// =====================================================================

@HiltViewModel
class FounderAmcEscalationsViewModel @Inject constructor(
    private val repo: FounderRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val error: String? = null,
        val rows: List<FounderRepository.AmcEscalation> = emptyList(),
        val acting: Set<String> = emptySet(),
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload(initial = true) }
    fun onPullToRefresh() = reload(initial = false)

    fun reload(initial: Boolean = false) {
        _state.update {
            it.copy(
                loading = initial || it.rows.isEmpty(),
                refreshing = !initial && it.rows.isNotEmpty(),
                error = null,
            )
        }
        viewModelScope.launch {
            repo.fetchOpenAmcEscalations()
                .onSuccess { rows -> _state.update { it.copy(loading = false, refreshing = false, rows = rows) } }
                .onFailure { e -> _state.update { it.copy(loading = false, refreshing = false, error = e.toUserMessage()) } }
        }
    }

    fun resolve(escalationId: String) {
        if (_state.value.acting.contains(escalationId)) return
        _state.update { it.copy(acting = it.acting + escalationId, error = null) }
        viewModelScope.launch {
            repo.resolveAmcEscalation(escalationId, notes = "Resolved via admin dashboard")
                .onSuccess {
                    _state.update {
                        it.copy(
                            acting = it.acting - escalationId,
                            rows = it.rows.filterNot { r -> r.escalationId == escalationId },
                        )
                    }
                }
                .onFailure { e ->
                    _state.update { it.copy(acting = it.acting - escalationId, error = e.toUserMessage()) }
                }
        }
    }
}

@Composable
fun FounderAmcEscalationsScreen(
    onBack: () -> Unit,
    onOpenDetail: (escalationId: String) -> Unit = {},
    viewModel: FounderAmcEscalationsViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    // Round 429 — refresh on return.
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }
    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(
                title = "AMC escalations",
                subtitle = simpleQueueCountSubtitle(state.rows.size, "open"),
                onBack = onBack,
            )
            QueueBox(
                loading = state.loading,
                error = state.error,
                empty = state.rows.isEmpty(),
                emptyTitle = "No open escalations",
                emptySubtitle = "Rotation auto-assigns; nothing exhausted.",
                refreshing = state.refreshing,
                onRefresh = viewModel::onPullToRefresh,
            ) {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(12.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    items(state.rows, key = { it.escalationId }) { row ->
                        AmcEscalationRow(
                            row = row,
                            acting = state.acting.contains(row.escalationId),
                            onResolve = { viewModel.resolve(row.escalationId) },
                            onOpenDetail = { onOpenDetail(row.escalationId) },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun AmcEscalationRow(
    row: FounderRepository.AmcEscalation,
    acting: Boolean,
    onResolve: () -> Unit,
    onOpenDetail: () -> Unit,
) {
    QueueCard {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    amcEscalationHospitalName(row.hospitalName),
                    color = SevaInk900,
                    fontWeight = FontWeight.Bold,
                    fontSize = 14.sp,
                )
                Text(
                    amcEscalationReasonLabel(row.reason),
                    color = SevaInk700,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium,
                )
            }
            val (text, kind) = amcEscalationPillTextAndKind(row.reason)
            Pill(text = text, kind = kind)
        }
        Text(
            amcEscalationContextLine(row.visitNumber, row.amcContractId),
            color = SevaInk500,
            fontSize = 11.sp,
        )
        if (!row.notes.isNullOrBlank()) {
            Text(row.notes, color = SevaInk700, fontSize = 13.sp)
        }
        if (!row.createdAt.isNullOrBlank()) {
            Text("Raised: ${prettyDateTime(row.createdAt)}", color = SevaInk500, fontSize = 11.sp)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            EsBtn(
                text = "View detail",
                kind = EsBtnKind.Secondary,
                size = EsBtnSize.Sm,
                onClick = onOpenDetail,
                modifier = Modifier.weight(1f),
            )
            EsBtn(
                text = if (acting) "..." else "Mark resolved",
                kind = EsBtnKind.Primary,
                size = EsBtnSize.Sm,
                disabled = acting,
                onClick = onResolve,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

// =====================================================================
// 3. Cash-flagged engineers queue
// =====================================================================

@HiltViewModel
class FounderCashSuspendedViewModel @Inject constructor(
    private val repo: FounderRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val error: String? = null,
        val rows: List<FounderRepository.CashSuspendedEngineer> = emptyList(),
        val acting: Set<String> = emptySet(),
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload(initial = true) }
    fun onPullToRefresh() = reload(initial = false)

    fun reload(initial: Boolean = false) {
        _state.update {
            it.copy(
                loading = initial || it.rows.isEmpty(),
                refreshing = !initial && it.rows.isNotEmpty(),
                error = null,
            )
        }
        viewModelScope.launch {
            repo.fetchCashSuspendedEngineers()
                .onSuccess { rows -> _state.update { it.copy(loading = false, refreshing = false, rows = rows) } }
                .onFailure { e -> _state.update { it.copy(loading = false, refreshing = false, error = e.toUserMessage()) } }
        }
    }

    fun clear(engineerId: String) {
        if (_state.value.acting.contains(engineerId)) return
        _state.update { it.copy(acting = it.acting + engineerId, error = null) }
        viewModelScope.launch {
            repo.clearCashAutoSuspension(engineerId, note = "Cleared via admin dashboard")
                .onSuccess {
                    _state.update {
                        it.copy(
                            acting = it.acting - engineerId,
                            rows = it.rows.filterNot { r -> r.engineerId == engineerId },
                        )
                    }
                }
                .onFailure { e ->
                    _state.update { it.copy(acting = it.acting - engineerId, error = e.toUserMessage()) }
                }
        }
    }
}

@Composable
fun FounderCashSuspendedScreen(
    onBack: () -> Unit,
    onOpenHistory: (engineerId: String) -> Unit = {},
    viewModel: FounderCashSuspendedViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    // Round 429 — refresh on return.
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }
    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(
                title = "Cash-flag suspensions",
                subtitle = simpleQueueCountSubtitle(state.rows.size, "suspended"),
                onBack = onBack,
            )
            QueueBox(
                loading = state.loading,
                error = state.error,
                empty = state.rows.isEmpty(),
                emptyTitle = "Nobody auto-suspended",
                emptySubtitle = "Engineers crossing 3 cash-flags / 90 days land here.",
                refreshing = state.refreshing,
                onRefresh = viewModel::onPullToRefresh,
            ) {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(12.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    items(state.rows, key = { it.engineerId }) { row ->
                        CashSuspendedRow(
                            row = row,
                            acting = state.acting.contains(row.engineerId),
                            onClear = { viewModel.clear(row.engineerId) },
                            onOpenHistory = { onOpenHistory(row.engineerId) },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun CashSuspendedRow(
    row: FounderRepository.CashSuspendedEngineer,
    acting: Boolean,
    onClear: () -> Unit,
    onOpenHistory: () -> Unit,
) {
    QueueCard {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    cashSuspendedRowName(row.fullName),
                    color = SevaInk900,
                    fontWeight = FontWeight.Bold,
                    fontSize = 14.sp,
                )
                Text(
                    cashSuspendedFlagCountLabel(row.flagCount90d),
                    color = SevaDanger500,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                )
            }
            Pill(text = "Suspended", kind = PillKind.Danger)
        }
        if (!row.reason.isNullOrBlank()) {
            Text(row.reason, color = SevaInk700, fontSize = 13.sp)
        }
        if (!row.suspendedAt.isNullOrBlank()) {
            Text("Since: ${prettyDateTime(row.suspendedAt)}", color = SevaInk500, fontSize = 11.sp)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            EsBtn(
                text = "View history",
                kind = EsBtnKind.Secondary,
                size = EsBtnSize.Sm,
                onClick = onOpenHistory,
                modifier = Modifier.weight(1f),
            )
            EsBtn(
                text = if (acting) "..." else "Clear suspension",
                kind = EsBtnKind.Primary,
                size = EsBtnSize.Sm,
                disabled = acting,
                onClick = onClear,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

// =====================================================================
// 4. Parts-cost outliers queue
// =====================================================================

@HiltViewModel
class FounderPartsOutliersViewModel @Inject constructor(
    private val repo: FounderRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val error: String? = null,
        val rows: List<FounderRepository.PartsCostOutlier> = emptyList(),
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload(initial = true) }
    fun onPullToRefresh() = reload(initial = false)

    fun reload(initial: Boolean = false) {
        _state.update {
            it.copy(
                loading = initial || it.rows.isEmpty(),
                refreshing = !initial && it.rows.isNotEmpty(),
                error = null,
            )
        }
        viewModelScope.launch {
            repo.fetchPartsCostOutliers()
                .onSuccess { rows -> _state.update { it.copy(loading = false, refreshing = false, rows = rows) } }
                .onFailure { e -> _state.update { it.copy(loading = false, refreshing = false, error = e.toUserMessage()) } }
        }
    }
}

@Composable
fun FounderPartsOutliersScreen(
    onBack: () -> Unit,
    viewModel: FounderPartsOutliersViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    // Round 429 — refresh on return.
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }
    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(
                title = "Parts-cost outliers",
                subtitle = partsOutliersSubtitle(state.rows.size),
                onBack = onBack,
            )
            QueueBox(
                loading = state.loading,
                error = state.error,
                empty = state.rows.isEmpty(),
                emptyTitle = "No outliers in 90 days",
                emptySubtitle = "Parts charges all within 5× category average.",
                refreshing = state.refreshing,
                onRefresh = viewModel::onPullToRefresh,
            ) {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(12.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    items(state.rows, key = { it.repairJobId }) { row -> PartsOutlierRow(row) }
                }
            }
        }
    }
}

@Composable
private fun PartsOutlierRow(row: FounderRepository.PartsCostOutlier) {
    QueueCard {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    partsOutlierRowTitle(row.jobNumber, row.repairJobId),
                    color = SevaInk900,
                    fontWeight = FontWeight.Bold,
                    fontSize = 14.sp,
                )
                Text(
                    partsOutlierEquipmentTypeLabel(row.equipmentType),
                    color = SevaInk700,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium,
                )
            }
            Pill(text = partsOutlierRatioPillText(row.ratio), kind = PillKind.Warn)
        }
        Text(
            partsOutlierComparisonLine(row.partsCost, row.categoryAvgParts),
            color = SevaInk700,
            fontSize = 13.sp,
        )
        Text(
            partsOutlierPartiesLine(row.engineerName, row.hospitalName),
            color = SevaInk500,
            fontSize = 12.sp,
        )
        if (!row.completedAt.isNullOrBlank()) {
            Text("Completed: ${prettyDate(row.completedAt)}", color = SevaInk500, fontSize = 11.sp)
        }
    }
}

// =====================================================================
// shared bits
// =====================================================================

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
private fun QueueBox(
    loading: Boolean,
    error: String?,
    empty: Boolean,
    emptyTitle: String,
    emptySubtitle: String,
    // Round 400 — optional pull-to-refresh. When both are provided, the
    // inner content is wrapped in a PullToRefreshBox so every OpsQueue
    // screen gains in-screen refresh symmetric with the r378-399 sweep.
    refreshing: Boolean = false,
    onRefresh: (() -> Unit)? = null,
    content: @Composable () -> Unit,
) {
    val body: @Composable () -> Unit = {
        when {
            loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
            error != null -> EmptyStateView(
                icon = Icons.Outlined.Inbox,
                title = "Couldn't load",
                subtitle = error,
            )
            empty -> EmptyStateView(
                icon = Icons.Outlined.Inbox,
                title = emptyTitle,
                subtitle = emptySubtitle,
            )
            else -> content()
        }
    }
    if (onRefresh != null) {
        androidx.compose.material3.pulltorefresh.PullToRefreshBox(
            isRefreshing = refreshing,
            onRefresh = onRefresh,
            modifier = Modifier.fillMaxSize(),
        ) { body() }
    } else {
        Box(modifier = Modifier.fillMaxSize()) { body() }
    }
}

@Composable
private fun QueueCard(content: @Composable androidx.compose.foundation.layout.ColumnScope.() -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
        content = content,
    )
}

// =====================================================================
// PR-D32 — Admin resolve-dispute sheet (outcome radio + note field)
// =====================================================================

@Composable
private fun AdminResolveDisputeSheet(
    target: FounderRepository.EscrowDispute?,
    submitting: Boolean,
    onDismiss: () -> Unit,
    onSubmit: (outcome: String, note: String?) -> Unit,
) {
    var outcome by rememberSaveable { mutableStateOf("release") }
    var note by rememberSaveable { mutableStateOf("") }
    EsBottomSheet(onClose = onDismiss, title = "Resolve dispute") {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            target?.let {
                Text(
                    "${it.jobNumber ?: "RPR-${it.repairJobId.take(6)}"} · ${formatRupees(it.amountRupees)} held",
                    color = SevaInk900,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 13.sp,
                )
                if (!it.disputeReason.isNullOrBlank()) {
                    Text(
                        "Hospital: ${it.disputeReason}",
                        color = SevaInk700,
                        fontSize = 12.sp,
                    )
                }
            }
            Text(
                "Pick an outcome and (optionally) record a short note explaining the call. Note appears in the audit timeline.",
                color = SevaInk500,
                fontSize = 12.sp,
            )
            OutcomeOption(
                label = "Release to engineer",
                sub = "Funds clear to engineer's payout queue.",
                selected = outcome == "release",
                onClick = { outcome = "release" },
            )
            OutcomeOption(
                label = "Refund hospital",
                sub = "Funds return to the hospital. Engineer paid nothing.",
                selected = outcome == "refund",
                onClick = { outcome = "refund" },
            )
            OutlinedTextField(
                value = note,
                onValueChange = { if (it.length <= 500) note = it },
                modifier = Modifier.fillMaxWidth(),
                placeholder = { Text("e.g. Engineer's response confirmed by completion photos and hospital sign-off log.") },
                minLines = 2,
                maxLines = 5,
            )
            EsBtn(
                text = if (submitting) "Submitting…" else "Confirm resolution",
                kind = EsBtnKind.Primary,
                size = EsBtnSize.Md,
                disabled = submitting,
                full = true,
                onClick = {
                    onSubmit(outcome, note.trim().takeIf { it.isNotBlank() })
                },
            )
        }
    }
}

@Composable
private fun OutcomeOption(
    label: String,
    sub: String,
    selected: Boolean,
    onClick: () -> Unit,
) {
    Row(
        // Round 447 — Release / Refund picks are an exclusive radio group
        // inside the AdminResolveDisputeSheet. selectable + Role.RadioButton
        // gives TalkBack the proper "Radio button, selected/not selected"
        // announce. Sibling to r445/r446.
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(Color.White)
            .border(
                width = 1.dp,
                color = if (selected) SevaDanger500 else BorderDefault,
                shape = RoundedCornerShape(10.dp),
            )
            .selectable(
                selected = selected,
                onClick = onClick,
                role = Role.RadioButton,
            )
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Box(
            modifier = Modifier
                .padding(top = 2.dp)
                .clip(RoundedCornerShape(50))
                .background(if (selected) SevaDanger500 else Color.Transparent)
                .border(
                    width = 1.dp,
                    color = if (selected) SevaDanger500 else BorderDefault,
                    shape = RoundedCornerShape(50),
                )
                .padding(6.dp),
        ) { Box(modifier = Modifier.padding(2.dp)) {} }
        Column(modifier = Modifier.weight(1f)) {
            Text(label, color = SevaInk900, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
            Text(sub, color = SevaInk500, fontSize = 11.sp)
        }
    }
}

/**
 * Title for an escrow-dispute row on the founder ops queue.
 *
 *   * Server-provided jobNumber → use as-is (preferred)
 *   * Fallback → "RPR-${first 6 chars of repairJobId}" — pin the
 *     6-char prefix so a future change is reviewed (must match the
 *     UI's tap-target so a founder hunting for the row in another
 *     queue gets a consistent identifier).
 */
internal fun escrowDisputeRowTitle(jobNumber: String?, repairJobId: String): String =
    jobNumber ?: "RPR-${repairJobId.take(6)}"

/**
 * Hospital → engineer parties line on an escrow-dispute row.
 * Mirrors the dev-placeholder safety check used elsewhere
 * (cashSuspendedRowName / amcVisitHospitalName) — blank names fold
 * to "Hospital" / "Engineer" generic labels so the founder doesn't
 * see "(unnamed) → (unnamed)" on rows where the join failed.
 *
 * Unicode rightwards arrow (U+2192) pinned — pin so an ASCII "->"
 * fragmentation doesn't surface.
 */
internal fun escrowDisputePartiesLine(hospitalName: String?, engineerName: String?): String {
    val h = hospitalName?.takeIf { it.isNotBlank() } ?: "Hospital"
    val e = engineerName?.takeIf { it.isNotBlank() } ?: "Engineer"
    return "$h → $e"
}

/**
 * Display name for a cash-suspended engineer row on the founder
 * ops queue. Blank/null → "Engineer" generic fallback. Mirrors the
 * AMC-visit row's [amcVisitHospitalName] pattern — pin so the same
 * dev-placeholder safety check applies on both surfaces.
 */
internal fun cashSuspendedRowName(fullName: String?): String =
    fullName?.takeIf { it.isNotBlank() } ?: "Engineer"

/**
 * "N flags / 90d" subtitle on the cash-suspended row. Always plural
 * "flags" — the suspension trigger requires 3+ flags in 90 days, so
 * 1-flag rows shouldn't appear; if they do (race / manual flag
 * removal), pluralisation is still correct because the window
 * cadence reads as "flags per 90d" regardless of count.
 *
 * Pin so the unit "/ 90d" stays intact — load-bearing rolling-window
 * context the founder uses to decide whether to clear.
 */
internal fun cashSuspendedFlagCountLabel(flagCount90d: Int): String =
    "$flagCount90d flags / 90d"

/**
 * Hospital-name fallback on the founder's AMC-escalation row. Mirrors
 * [cashSuspendedRowName] — null/blank reads as the role label so an
 * incomplete row stays addressable. Pin so a backfill bug that lands a
 * blank hospital name doesn't surface a naked "·" or a dev-placeholder
 * on the founder's escalation triage queue.
 */
internal fun amcEscalationHospitalName(hospitalName: String?): String =
    hospitalName?.takeIf { it.isNotBlank() } ?: "Hospital"

/**
 * Reason label on the AMC-escalation row. The wire stores
 * `snake_case` reason codes (`rotation_exhausted`, `engineer_unavailable`,
 * `parts_delayed`, …); we render them as Title-cased prose with
 * underscores → spaces and first-letter capitalised.
 *
 * Pin so a refactor to a lookup table doesn't accidentally drop the
 * underscore→space step (would surface "Rotation_exhausted") or skip
 * the first-letter capitalisation (would surface "rotation exhausted",
 * which reads as a sentence fragment in the row header).
 */
internal fun amcEscalationReasonLabel(reason: String): String =
    reason.replace('_', ' ').replaceFirstChar { it.uppercase() }

/**
 * Pill text + colour kind for the AMC-escalation row.
 *
 * Critical region: `rotation_exhausted` is the ONLY reason that warrants
 * the Danger pill — it means every engineer in the geographic pool has
 * declined or already done their max visits, and the contract is now
 * unstaffable without manual founder intervention. Every other reason
 * is a Warn (recoverable: a different engineer can be assigned, parts
 * can be sourced, etc.).
 *
 * Pin the exact wire string + the binary pill split so a refactor that
 * renamed the wire code (e.g. to `pool_exhausted`) surfaces as a test
 * failure rather than silently downgrading the urgency cue to Warn.
 */
internal fun amcEscalationPillTextAndKind(reason: String): Pair<String, PillKind> =
    if (reason == "rotation_exhausted") {
        "Exhausted" to PillKind.Danger
    } else {
        "Open" to PillKind.Warn
    }

/**
 * Context subline on the AMC-escalation row: "Visit #N · contract XXXXXXXX"
 * (or just "Contract XXXXXXXX" when the visit number is null — an
 * escalation can be raised against a contract before any visits have
 * been scheduled).
 *
 * Pin so the U+00B7 middle-dot separator survives, the contract-id
 * `take(8)` truncation stays (load-bearing — the founder uses the
 * 8-char prefix to cross-reference the AMC detail screen), and the
 * null-visit branch keeps "Contract" with a capital C (the
 * non-null branch already has "Visit #N ·" leading, so "contract" is
 * lowercase there — a refactor that unified the casing would surface
 * either as wrong on the no-visit row or wrong on the with-visit row).
 */
internal fun amcEscalationContextLine(visitNumber: Int?, amcContractId: String): String =
    if (visitNumber != null) {
        "Visit #$visitNumber · contract ${amcContractId.take(8)}"
    } else {
        "Contract ${amcContractId.take(8)}"
    }

/**
 * Title on the parts-cost-outlier row: prefer the server-issued
 * `jobNumber` (e.g. "RPR-2026-00041"), fall back to a synthetic
 * "RPR-${first 6 chars of repairJobId}".
 *
 * Pin take(6) (not take(8) like the AMC contract case) — the outlier
 * queue uses 6 because the matching server jobNumber suffix is also 6
 * digits (year-prefixed). A refactor that unified the prefix length
 * across queues would silently shift this and confuse the founder
 * doing manual lookups.
 */
internal fun partsOutlierRowTitle(jobNumber: String?, repairJobId: String): String =
    jobNumber ?: "RPR-${repairJobId.take(6)}"

/**
 * Equipment-type label on the parts-cost-outlier row. The wire stores
 * enum codes like `mri_scanner`, `ct_scanner`, `xray` — we render them
 * as Title-cased prose with underscores → spaces and first-letter
 * capitalised. Null/blank reads as "Unknown".
 *
 * Pin the "Unknown" fallback so a row with a missing equipment type
 * (legacy data) stays addressable rather than rendering as an empty
 * row subtitle that breaks the row's visual hierarchy.
 */
internal fun partsOutlierEquipmentTypeLabel(equipmentType: String?): String =
    equipmentType?.replace('_', ' ')?.replaceFirstChar { it.uppercase() } ?: "Unknown"

/**
 * Ratio pill text on the parts-cost-outlier row: "%.1fx" with the
 * U+00D7 multiplication sign (NOT ASCII 'x').
 *
 * Critical region:
 *   1. Locale.US — Hindi-locale would render "3,2×" (comma decimal)
 *      and break the founder's number parsing intuition.
 *   2. One decimal — pin so a refactor to %d (integer) doesn't lose
 *      precision (the 5x threshold means most rows cluster in 5.0–8.0
 *      and the .x digit is load-bearing for triage prioritisation).
 *   3. U+00D7 — pin the proper multiplication sign survives.
 */
internal fun partsOutlierRatioPillText(ratio: Double): String =
    "${"%.1f".format(java.util.Locale.US, ratio)}×"

/**
 * Comparison line on the parts-cost-outlier row:
 * "Parts ₹X vs category avg ₹Y" with both values run through
 * [formatRupees] (Indian-lakh grouping). Pin the literal "vs category
 * avg" phrasing — a refactor that changed it to "Category avg ₹Y"
 * would break the founder's mental model of which number is the
 * outlier and which is the baseline.
 */
internal fun partsOutlierComparisonLine(partsCost: Double, categoryAvgParts: Double): String =
    "Parts ${formatRupees(partsCost)} vs category avg ${formatRupees(categoryAvgParts)}"

/**
 * Parties line on the parts-cost-outlier row: "Engineer → Hospital"
 * with the U+2192 rightwards arrow and null/blank fallbacks for
 * either side.
 *
 * Pin so:
 *   1. The U+2192 arrow (NOT "->" or "→ ") survives — visual symmetry
 *      with the other founder ops-queue arrows.
 *   2. The role labels ("Engineer", "Hospital") appear capitalised —
 *      a backfill row missing both names still reads as
 *      "Engineer → Hospital", not " → " or "engineer → hospital".
 */
internal fun partsOutlierPartiesLine(engineerName: String?, hospitalName: String?): String {
    val eng = engineerName?.takeIf { it.isNotBlank() } ?: "Engineer"
    val hos = hospitalName?.takeIf { it.isNotBlank() } ?: "Hospital"
    return "$eng → $hos"
}

/**
 * Amount-held subline on the founder escrow-dispute row: "₹X held".
 *
 * Pin the trailing " held" — load-bearing escrow-state context. A
 * dispute row says HELD (the money is locked pending resolution);
 * a resolved row says RELEASED or REFUNDED elsewhere. A refactor
 * that dropped the suffix would lose the state signal.
 */
internal fun escrowDisputeAmountHeldLine(amountRupees: Double): String =
    "${formatRupees(amountRupees)} held"

/**
 * Subtitle on the founder Parts-Cost-Outliers top bar.
 *
 * Returns null on empty list. Otherwise reads "N >5x category avg"
 * — the "5x" is the LITERAL threshold the server-side outlier query
 * uses (charges > 5× the category average). Pin so a refactor that
 * relaxed to 4x or tightened to 6x without updating the server-side
 * threshold would surface here as a mismatch.
 *
 * Pin the ">5x" form (ASCII `>` + lowercase `x`) — distinct from the
 * row-level pill text which uses "%.1f×" with the U+00D7 sign and
 * decimal precision. The subtitle uses the bare integer threshold
 * because it describes the cohort, not an individual row.
 */
internal fun partsOutliersSubtitle(rowCount: Int): String? =
    if (rowCount > 0) "$rowCount >5x category avg" else null

/**
 * Shared subtitle helper for founder ops-queue tabs that use the
 * pattern "$count $noun" (e.g. "5 open", "3 suspended").
 *
 *   - rowCount <= 0 → null (top bar stays clean on cold-load)
 *   - rowCount > 0 → "$rowCount $noun"
 *
 * Callers pass the surface-specific status noun:
 *   - Escrow disputes: "open"
 *   - AMC escalations: "open"
 *   - Cash-flag suspensions: "suspended"
 *
 * Pin the shared shape so a refactor that diverged one queue (e.g.
 * "5 open · last 30d") would need to drop this helper rather than
 * silently shift the format on the others.
 *
 * Pin plural-blind shape — singular "1 open" / "1 suspended" reads
 * fine because the status is a state, not a count-noun.
 */
internal fun simpleQueueCountSubtitle(rowCount: Int, statusNoun: String): String? =
    if (rowCount > 0) "$rowCount $statusNoun" else null
