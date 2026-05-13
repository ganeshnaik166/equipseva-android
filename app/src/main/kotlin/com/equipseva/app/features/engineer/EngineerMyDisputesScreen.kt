package com.equipseva.app.features.engineer

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
class EngineerMyDisputesViewModel @Inject constructor(
    private val escrowRepo: RepairJobEscrowRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val rows: List<RepairJobEscrowRepository.EngineerDisputeRow> = emptyList(),
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload() }

    fun reload() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            escrowRepo.fetchEngineerDisputeHistory()
                .onSuccess { rows -> _state.update { it.copy(loading = false, rows = rows) } }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.toUserMessage()) } }
        }
    }
}

/**
 * v2.1 PR-D42 — engineer self-view of disputes received. Symmetric
 * mirror of the hospital-side D41 screen.
 */
@Composable
fun EngineerMyDisputesScreen(
    onBack: () -> Unit,
    onOpenJob: (repairJobId: String) -> Unit,
    viewModel: EngineerMyDisputesViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    // Picks up admin resolutions on return.
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }
    val openCount = state.rows.count { it.status == "in_dispute" }
    val wonCount = state.rows.count { it.outcome == "release" }
    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(
                title = "Disputes received",
                subtitle = state.rows.size.takeIf { it > 0 }?.let {
                    "$openCount open · $wonCount released to you · last 12 months"
                },
                onBack = onBack,
            )
            Box(modifier = Modifier.fillMaxSize()) {
                when {
                    state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                    state.error != null -> EmptyStateView(
                        icon = Icons.Outlined.Gavel,
                        title = "Couldn't load",
                        subtitle = state.error,
                    )
                    state.rows.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.Gavel,
                        title = "No disputes",
                        subtitle = "If a hospital opens a dispute on a job you completed, it'll appear here so you can respond.",
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
    row: RepairJobEscrowRepository.EngineerDisputeRow,
    onClick: () -> Unit,
) {
    val (pillText, pillKind) = when {
        row.status == "in_dispute" -> "Under review" to PillKind.Danger
        // Engineer's "won" = funds released to engineer.
        row.outcome == "release" -> "Released to you" to PillKind.Success
        row.outcome == "refund" -> "Refunded to hospital" to PillKind.Warn
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
                    // Mirror rounds 37 + 53: "(unnamed hospital)" reads
                    // as a missing-data bug to engineers, not as a
                    // fallback. Collapse blank/null names to the row
                    // category — "Hospital".
                    "${formatRupees(row.amountRupees)} · ${row.hospitalName?.takeIf { it.isNotBlank() } ?: "Hospital"}",
                    color = SevaInk700,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium,
                )
            }
            Pill(text = pillText, kind = pillKind)
        }
        if (!row.disputeReason.isNullOrBlank()) {
            Text("Hospital: ${row.disputeReason}", color = SevaInk700, fontSize = 12.sp)
        }
        if (!row.engineerResponse.isNullOrBlank()) {
            Text("You: ${row.engineerResponse}", color = SevaInk700, fontSize = 12.sp)
        }
        if (!row.resolutionNote.isNullOrBlank()) {
            Text(
                "EquipSeva note: ${row.resolutionNote}",
                color = SevaInk900,
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium,
            )
        }
        row.disputeOpenedAt?.let {
            Text("Opened: ${prettyDate(it)}", color = SevaInk500, fontSize = 11.sp)
        }
        row.disputeResolvedAt?.let {
            Text("Resolved: ${prettyDate(it)}", color = SevaInk500, fontSize = 11.sp)
        }
    }
}
