package com.equipseva.app.features.founder

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.designsystem.components.EmptyStateView
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
        val error: String? = null,
        val rows: List<FounderRepository.EscrowDispute> = emptyList(),
        val acting: Set<String> = emptySet(),
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload() }

    fun reload() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            repo.fetchOpenEscrowDisputes()
                .onSuccess { rows -> _state.update { it.copy(loading = false, rows = rows) } }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.toUserMessage()) } }
        }
    }

    fun resolve(escrowId: String, outcome: String) {
        if (_state.value.acting.contains(escrowId)) return
        _state.update { it.copy(acting = it.acting + escrowId, error = null) }
        viewModelScope.launch {
            repo.resolveEscrowDispute(escrowId, outcome)
                .onSuccess {
                    _state.update {
                        it.copy(
                            acting = it.acting - escrowId,
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
    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(
                title = "Escrow disputes",
                subtitle = state.rows.size.takeIf { it > 0 }?.let { "$it open" },
                onBack = onBack,
            )
            QueueBox(
                loading = state.loading,
                error = state.error,
                empty = state.rows.isEmpty(),
                emptyTitle = "No active disputes",
                emptySubtitle = "Hospitals haven't disputed any held escrows.",
            ) {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(12.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    items(state.rows, key = { it.escrowId }) { row ->
                        EscrowDisputeRow(
                            row = row,
                            acting = state.acting.contains(row.escrowId),
                            onAction = { outcome -> viewModel.resolve(row.escrowId, outcome) },
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
    acting: Boolean,
    onAction: (String) -> Unit,
    onOpenTimeline: () -> Unit,
) {
    QueueCard {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    row.jobNumber ?: "RPR-${row.repairJobId.take(6)}",
                    color = SevaInk900,
                    fontWeight = FontWeight.Bold,
                    fontSize = 14.sp,
                )
                Text(
                    "₹${"%.0f".format(row.amountRupees)} held",
                    color = SevaInk700,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium,
                )
            }
            Pill(text = "Disputed", kind = PillKind.Danger)
        }
        Text(
            "${row.hospitalName ?: "(unnamed)"} → ${row.engineerName ?: "(unnamed)"}",
            color = SevaInk500,
            fontSize = 12.sp,
        )
        if (!row.disputeReason.isNullOrBlank()) {
            Text(row.disputeReason, color = SevaInk700, fontSize = 13.sp)
        }
        if (!row.disputeOpenedAt.isNullOrBlank()) {
            Text("Opened: ${row.disputeOpenedAt.take(19).replace('T', ' ')}", color = SevaInk500, fontSize = 11.sp)
        }
        EsBtn(
            text = "View timeline",
            kind = EsBtnKind.Secondary,
            size = EsBtnSize.Sm,
            onClick = onOpenTimeline,
            full = true,
        )
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            EsBtn(
                text = if (acting) "..." else "Release to engineer",
                kind = EsBtnKind.Primary,
                size = EsBtnSize.Sm,
                disabled = acting,
                onClick = { onAction("release") },
                modifier = Modifier.weight(1f),
            )
            EsBtn(
                text = if (acting) "..." else "Refund hospital",
                kind = EsBtnKind.Secondary,
                size = EsBtnSize.Sm,
                disabled = acting,
                onClick = { onAction("refund") },
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
        val error: String? = null,
        val rows: List<FounderRepository.AmcEscalation> = emptyList(),
        val acting: Set<String> = emptySet(),
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload() }

    fun reload() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            repo.fetchOpenAmcEscalations()
                .onSuccess { rows -> _state.update { it.copy(loading = false, rows = rows) } }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.toUserMessage()) } }
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
    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(
                title = "AMC escalations",
                subtitle = state.rows.size.takeIf { it > 0 }?.let { "$it open" },
                onBack = onBack,
            )
            QueueBox(
                loading = state.loading,
                error = state.error,
                empty = state.rows.isEmpty(),
                emptyTitle = "No open escalations",
                emptySubtitle = "Rotation auto-assigns; nothing exhausted.",
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
                    row.hospitalName ?: "(unnamed)",
                    color = SevaInk900,
                    fontWeight = FontWeight.Bold,
                    fontSize = 14.sp,
                )
                Text(
                    row.reason.replace('_', ' ').replaceFirstChar { it.uppercase() },
                    color = SevaInk700,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium,
                )
            }
            Pill(
                text = if (row.reason == "rotation_exhausted") "Exhausted" else "Open",
                kind = if (row.reason == "rotation_exhausted") PillKind.Danger else PillKind.Warn,
            )
        }
        if (row.visitNumber != null) {
            Text(
                "Visit #${row.visitNumber} · contract ${row.amcContractId.take(8)}",
                color = SevaInk500,
                fontSize = 11.sp,
            )
        } else {
            Text(
                "Contract ${row.amcContractId.take(8)}",
                color = SevaInk500,
                fontSize = 11.sp,
            )
        }
        if (!row.notes.isNullOrBlank()) {
            Text(row.notes, color = SevaInk700, fontSize = 13.sp)
        }
        if (!row.createdAt.isNullOrBlank()) {
            Text("Raised: ${row.createdAt.take(19).replace('T', ' ')}", color = SevaInk500, fontSize = 11.sp)
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
        val error: String? = null,
        val rows: List<FounderRepository.CashSuspendedEngineer> = emptyList(),
        val acting: Set<String> = emptySet(),
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload() }

    fun reload() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            repo.fetchCashSuspendedEngineers()
                .onSuccess { rows -> _state.update { it.copy(loading = false, rows = rows) } }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.toUserMessage()) } }
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
    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(
                title = "Cash-flag suspensions",
                subtitle = state.rows.size.takeIf { it > 0 }?.let { "$it suspended" },
                onBack = onBack,
            )
            QueueBox(
                loading = state.loading,
                error = state.error,
                empty = state.rows.isEmpty(),
                emptyTitle = "Nobody auto-suspended",
                emptySubtitle = "Engineers crossing 3 cash-flags / 90 days land here.",
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
                    row.fullName ?: "(unnamed)",
                    color = SevaInk900,
                    fontWeight = FontWeight.Bold,
                    fontSize = 14.sp,
                )
                Text(
                    "${row.flagCount90d} flags / 90d",
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
            Text("Since: ${row.suspendedAt.take(19).replace('T', ' ')}", color = SevaInk500, fontSize = 11.sp)
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
        val error: String? = null,
        val rows: List<FounderRepository.PartsCostOutlier> = emptyList(),
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload() }

    fun reload() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            repo.fetchPartsCostOutliers()
                .onSuccess { rows -> _state.update { it.copy(loading = false, rows = rows) } }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.toUserMessage()) } }
        }
    }
}

@Composable
fun FounderPartsOutliersScreen(
    onBack: () -> Unit,
    viewModel: FounderPartsOutliersViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(
                title = "Parts-cost outliers",
                subtitle = state.rows.size.takeIf { it > 0 }?.let { "$it >5x category avg" },
                onBack = onBack,
            )
            QueueBox(
                loading = state.loading,
                error = state.error,
                empty = state.rows.isEmpty(),
                emptyTitle = "No outliers in 90 days",
                emptySubtitle = "Parts charges all within 5× category average.",
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
                    row.jobNumber ?: "RPR-${row.repairJobId.take(6)}",
                    color = SevaInk900,
                    fontWeight = FontWeight.Bold,
                    fontSize = 14.sp,
                )
                Text(
                    row.equipmentType?.replace('_', ' ')?.replaceFirstChar { it.uppercase() } ?: "Unknown",
                    color = SevaInk700,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium,
                )
            }
            Pill(text = "${"%.1f".format(row.ratio)}×", kind = PillKind.Warn)
        }
        Text(
            "Parts ₹${"%.0f".format(row.partsCost)} vs category avg ₹${"%.0f".format(row.categoryAvgParts)}",
            color = SevaInk700,
            fontSize = 13.sp,
        )
        Text(
            "${row.engineerName ?: "(unnamed)"} → ${row.hospitalName ?: "(unnamed)"}",
            color = SevaInk500,
            fontSize = 12.sp,
        )
        if (!row.completedAt.isNullOrBlank()) {
            Text("Completed: ${row.completedAt.take(10)}", color = SevaInk500, fontSize = 11.sp)
        }
    }
}

// =====================================================================
// shared bits
// =====================================================================

@Composable
private fun QueueBox(
    loading: Boolean,
    error: String?,
    empty: Boolean,
    emptyTitle: String,
    emptySubtitle: String,
    content: @Composable () -> Unit,
) {
    Box(modifier = Modifier.fillMaxSize()) {
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
