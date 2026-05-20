package com.equipseva.app.features.hospital

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.material.icons.outlined.Gavel
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
import com.equipseva.app.core.data.escrow.RepairJobEscrowRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.core.util.prettyDate
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.PaperDefault
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

@HiltViewModel
class HospitalMyDisputesViewModel @Inject constructor(
    private val escrowRepo: RepairJobEscrowRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        // Round 387 — pull-to-refresh inline indicator.
        val refreshing: Boolean = false,
        val error: String? = null,
        val rows: List<RepairJobEscrowRepository.HospitalDisputeRow> = emptyList(),
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload(initial = true) }

    fun reload(initial: Boolean = false) {
        _state.update {
            it.copy(
                loading = initial || it.rows.isEmpty(),
                refreshing = !initial && it.rows.isNotEmpty(),
                error = null,
            )
        }
        viewModelScope.launch {
            escrowRepo.fetchHospitalDisputeHistory()
                .onSuccess { rows -> _state.update { it.copy(loading = false, refreshing = false, rows = rows) } }
                .onFailure { e -> _state.update { it.copy(loading = false, refreshing = false, error = e.toUserMessage()) } }
        }
    }
    fun onPullToRefresh() = reload(initial = false)
}

/**
 * v2.1 PR-D41 — hospital self-view of dispute filing history. Surfaces
 * resolutions they may have missed + soft self-check on filing pattern.
 */
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun HospitalMyDisputesScreen(
    onBack: () -> Unit,
    onOpenJob: (repairJobId: String) -> Unit,
    viewModel: HospitalMyDisputesViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    // Re-fetch on return from a job detail: a dispute can flip from
    // in_dispute → resolved (refund/release) while the hospital was in
    // the detail screen. The split openCount/resolvedCount header below
    // would otherwise show stale counts until restart.
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }

    // Round 434 — memoize the count walks so they don't re-fire on every
    // recomposition (PullToRefresh state ticks, scroll, realtime). Keyed
    // on state.rows so the cached value invalidates when the list itself
    // changes. Mirror of the r387 fix on EngineerMyDisputes.
    val openCount = androidx.compose.runtime.remember(state.rows) {
        state.rows.count { it.status == "in_dispute" }
    }
    val resolvedCount = androidx.compose.runtime.remember(state.rows) {
        state.rows.size - state.rows.count { it.status == "in_dispute" }
    }
    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(
                title = "Your disputes",
                subtitle = state.rows.size.takeIf { it > 0 }?.let {
                    "$openCount open · $resolvedCount resolved · last 12 months"
                },
                onBack = onBack,
            )
            // Round 387 — pull-to-refresh.
            androidx.compose.material3.pulltorefresh.PullToRefreshBox(
                isRefreshing = state.refreshing,
                onRefresh = viewModel::onPullToRefresh,
                modifier = Modifier.fillMaxSize(),
            ) {
                when {
                    state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                    state.error != null -> EmptyStateView(
                        icon = Icons.Outlined.Gavel,
                        title = "Couldn't load",
                        subtitle = state.error,
                        ctaLabel = "Try again",
                        onCta = { viewModel.reload() },
                    )
                    state.rows.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.Gavel,
                        title = "No disputes filed",
                        subtitle = "Disputes you open from a held escrow appear here for review.",
                    )
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(12.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        items(state.rows, key = { it.escrowId }) { row ->
                            DisputeRow(row = row, onClick = { onOpenJob(row.repairJobId) })
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun DisputeRow(
    row: RepairJobEscrowRepository.HospitalDisputeRow,
    onClick: () -> Unit,
) {
    val (pillText, pillKind) = when {
        row.status == "in_dispute" -> "Under review" to PillKind.Danger
        // "Released to engineer" was previously rendered with PillKind.Warn
        // (yellow) which reads as "in progress" — but for the hospital this
        // is a closed, unfavourable outcome (funds went to engineer). Render
        // it neutral instead so it doesn't compete with the green "Refunded
        // to you" success row in the same list.
        row.outcome == "release" -> "Released to engineer" to PillKind.Default
        row.outcome == "refund" -> "Refunded to you" to PillKind.Success
        else -> row.status.replaceFirstChar { it.uppercase() } to PillKind.Default
    }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    row.jobNumber ?: "RPR-${row.repairJobId.take(6)}",
                    color = SevaInk900,
                    fontWeight = FontWeight.Bold,
                    fontSize = 14.sp,
                )
                Text(
                    // The "(unnamed)" fallback read as a missing-data
                    // bug to hospital users. If the join didn't surface
                    // the engineer's display name (rare but happens
                    // with new accounts), the row category — "Engineer"
                    // — communicates the same thing without sounding
                    // like a dev placeholder.
                    "${formatRupees(row.amountRupees)} · ${row.engineerName?.takeIf { it.isNotBlank() } ?: "Engineer"}",
                    color = SevaInk700,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium,
                )
            }
            Pill(text = pillText, kind = pillKind)
        }
        if (!row.disputeReason.isNullOrBlank()) {
            Text(row.disputeReason, color = SevaInk700, fontSize = 12.sp)
        }
        if (!row.resolutionNote.isNullOrBlank()) {
            Text("EquipSeva note: ${row.resolutionNote}", color = SevaInk900, fontSize = 12.sp, fontWeight = FontWeight.Medium)
        }
        row.disputeOpenedAt?.let {
            Text("Opened: ${prettyDate(it)}", color = SevaInk500, fontSize = 11.sp)
        }
        row.disputeResolvedAt?.let {
            Text("Resolved: ${prettyDate(it)}", color = SevaInk500, fontSize = 11.sp)
        }
    }
}
