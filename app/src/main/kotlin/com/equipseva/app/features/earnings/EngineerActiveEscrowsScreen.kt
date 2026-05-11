package com.equipseva.app.features.earnings

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
import com.equipseva.app.core.data.escrow.RepairJobEscrowRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.core.util.prettyDateTime
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
class EngineerActiveEscrowsViewModel @Inject constructor(
    private val repo: RepairJobEscrowRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val rows: List<RepairJobEscrowRepository.ActiveEscrowRow> = emptyList(),
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload() }

    fun reload() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            repo.fetchEngineerActiveEscrows()
                .onSuccess { rows -> _state.update { it.copy(loading = false, rows = rows) } }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.toUserMessage()) } }
        }
    }
}

@Composable
fun EngineerActiveEscrowsScreen(
    onBack: () -> Unit,
    onOpenJob: (String) -> Unit,
    viewModel: EngineerActiveEscrowsViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(
                title = "Active escrows",
                subtitle = state.rows.size.takeIf { it > 0 }?.let { "$it open" },
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
                        title = "No funds in flight",
                        subtitle = "When a hospital pays into escrow on a job you accept, it lands here.",
                    )
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(12.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        items(state.rows, key = { it.escrowId }) { row ->
                            ActiveEscrowRow(row = row, onClick = { onOpenJob(row.repairJobId) })
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ActiveEscrowRow(
    row: RepairJobEscrowRepository.ActiveEscrowRow,
    onClick: () -> Unit,
) {
    val (pillText, pillKind) = when (row.status) {
        "in_dispute" -> "Disputed" to PillKind.Danger
        "held"       -> "Held" to PillKind.Success
        "pending"    -> "Awaiting payment" to PillKind.Warn
        else         -> row.status to PillKind.Default
    }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = row.jobNumber ?: "RPR-${row.repairJobId.take(6)}",
                    color = SevaInk900,
                    fontWeight = FontWeight.Bold,
                    fontSize = 14.sp,
                )
                Text(
                    text = formatRupees(row.amountRupees),
                    color = SevaInk700,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium,
                )
            }
            Pill(text = pillText, kind = pillKind)
        }
        Text(
            // Mirror rounds 37 / 53 / 54: "(unnamed hospital)" reads as a
            // missing-data bug to engineers, not as a fallback. Collapse
            // blank/null names to the row category — "Hospital".
            text = row.hospitalName?.takeIf { it.isNotBlank() } ?: "Hospital",
            color = SevaInk500,
            fontSize = 12.sp,
        )
        when (row.status) {
            "held" -> row.scheduledReleaseAt?.let {
                Text(
                    text = "Releases: ${prettyDateTime(it)}",
                    color = SevaInk500,
                    fontSize = 11.sp,
                )
            }
            "in_dispute" -> {
                row.disputeOpenedAt?.let {
                    Text(
                        text = "Disputed: ${prettyDateTime(it)}",
                        color = SevaInk500,
                        fontSize = 11.sp,
                    )
                }
                if (!row.disputeReason.isNullOrBlank()) {
                    Text(text = row.disputeReason, color = SevaInk700, fontSize = 12.sp)
                }
            }
            "pending" -> Text(
                // "Hospital must pay before you start work" implied the
                // engineer's check-in was the gate. The actual gate is
                // hospital payment → escrow funded → status flips. Use a
                // passive phrase that doesn't imply engineer action.
                text = "Awaiting hospital payment into escrow.",
                color = SevaInk500,
                fontSize = 11.sp,
            )
        }
    }
}
