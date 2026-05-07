package com.equipseva.app.features.founder

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
class FounderResolvedDisputesViewModel @Inject constructor(
    private val repo: FounderRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val rows: List<FounderRepository.ResolvedDispute> = emptyList(),
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload() }

    fun reload() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            repo.fetchRecentResolvedDisputes()
                .onSuccess { rows -> _state.update { it.copy(loading = false, rows = rows) } }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.toUserMessage()) } }
        }
    }
}

/**
 * v2.1 PR-D40 — admin ledger of recently resolved escrow disputes.
 * Sister to the open queue (PR-D21); rows that get resolved drop off
 * the open queue and surface here for review/audit.
 */
@Composable
fun FounderResolvedDisputesScreen(
    onBack: () -> Unit,
    onOpenTimeline: (escrowId: String) -> Unit,
    viewModel: FounderResolvedDisputesViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(
                title = "Resolved disputes",
                subtitle = state.rows.size.takeIf { it > 0 }?.let { "$it in last 30 days" },
                onBack = onBack,
            )
            Box(modifier = Modifier.fillMaxSize()) {
                when {
                    state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                    state.error != null -> EmptyStateView(
                        icon = Icons.Outlined.Inbox,
                        title = "Couldn't load",
                        subtitle = state.error,
                    )
                    state.rows.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.Inbox,
                        title = "No resolved disputes",
                        subtitle = "Disputes you resolve in the last 30 days land here.",
                    )
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(12.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        items(state.rows, key = { it.escrowId }) { row ->
                            ResolvedRow(row = row, onClick = { onOpenTimeline(row.escrowId) })
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ResolvedRow(
    row: FounderRepository.ResolvedDispute,
    onClick: () -> Unit,
) {
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
                    "₹${"%.0f".format(row.amountRupees)}",
                    color = SevaInk700,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium,
                )
            }
            Pill(
                text = if (row.outcome == "release") "Released" else "Refunded",
                kind = if (row.outcome == "release") PillKind.Success else PillKind.Warn,
            )
        }
        Text(
            "${row.hospitalName ?: "(unnamed)"} → ${row.engineerName ?: "(unnamed)"}",
            color = SevaInk500,
            fontSize = 12.sp,
        )
        if (!row.disputeReason.isNullOrBlank()) {
            Text("Hospital: ${row.disputeReason}", color = SevaInk700, fontSize = 12.sp)
        }
        if (!row.engineerResponse.isNullOrBlank()) {
            Text("Engineer: ${row.engineerResponse}", color = SevaInk700, fontSize = 12.sp)
        }
        if (!row.resolutionNote.isNullOrBlank()) {
            Text("Admin note: ${row.resolutionNote}", color = SevaInk900, fontSize = 12.sp, fontWeight = FontWeight.Medium)
        }
        row.resolvedAt?.let {
            Text(
                "Resolved: ${it.take(19).replace('T', ' ')}" +
                    (row.resolvedByName?.let { n -> " · $n" } ?: ""),
                color = SevaInk500,
                fontSize = 11.sp,
            )
        }
    }
}
