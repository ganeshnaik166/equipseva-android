package com.equipseva.app.features.founder

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Speed
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.founder.FounderSlaRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
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
class FounderSlaBoardViewModel @Inject constructor(
    private val repo: FounderSlaRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val rows: List<FounderSlaRepository.SlaRow> = emptyList(),
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload() }

    fun reload() {
        _state.update { it.copy(loading = it.rows.isEmpty(), error = null) }
        viewModelScope.launch {
            repo.board()
                .onSuccess { list -> _state.update { it.copy(loading = false, rows = list) } }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.toUserMessage()) } }
        }
    }
}

/**
 * Founder engineer-SLA board (r1424): engineers ranked by SLA health over the
 * last 30 days — on-time %, dispute rate, breaches, risk band and tier.
 * Surfaces engineer_sla_board() (founder-gated). Read-only; reached from the
 * founder business cockpit.
 */
@Composable
fun FounderSlaBoardScreen(
    onBack: () -> Unit,
    viewModel: FounderSlaBoardViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "Engineer SLA board", onBack = onBack)
            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                state.error != null -> EmptyStateView(
                    icon = Icons.Outlined.Speed,
                    title = "Couldn't load SLA board",
                    subtitle = state.error,
                    ctaLabel = "Try again",
                    onCta = { viewModel.reload() },
                )
                state.rows.isEmpty() -> EmptyStateView(
                    icon = Icons.Outlined.Speed,
                    title = "No engineer activity",
                    subtitle = "No completed jobs in the last 30 days to score.",
                )
                else -> LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(12.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    item(key = "hint") {
                        Text(
                            "Last 30 days · ranked by SLA risk",
                            style = EsType.Caption,
                            color = SevaInk500,
                            modifier = Modifier.padding(horizontal = 4.dp),
                        )
                    }
                    items(state.rows, key = { it.engineerEmail ?: it.hashCode().toString() }) { row -> SlaCard(row) }
                    item(key = "tail") { Spacer(Modifier.height(8.dp)) }
                }
            }
        }
    }
}

@Composable
private fun SlaCard(row: FounderSlaRepository.SlaRow) {
    val (bandText, bandKind) = slaRiskPill(row.currentRiskBand)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                row.engineerEmail ?: "Unknown engineer",
                style = EsType.Body.copy(fontWeight = FontWeight.Medium),
                color = SevaInk900,
                modifier = Modifier.weight(1f),
            )
            Pill(text = bandText, kind = bandKind)
        }
        Text(
            "On-time ${formatSlaPct(row.onTimePct)} · disputes ${formatSlaPct(row.disputeRatePct)} · ${row.slaBreaches} breaches",
            style = EsType.Caption,
            color = SevaInk700,
        )
        Text(
            "${row.jobsCompletedWindow} done (30d) · ${row.currentTier ?: "—"} tier" +
                (row.currentRiskScore?.let { " · risk $it" } ?: ""),
            style = EsType.Caption,
            color = SevaInk500,
        )
    }
}

// ---------------------------------------------------------------------
//  Pinned helpers
// ---------------------------------------------------------------------

/** Risk band → pill. low = healthy (Success), medium = watch (Warn),
 *  high/critical = at-risk (Danger); unknown is Neutral. */
internal fun slaRiskPill(band: String?): Pair<String, PillKind> = when (band?.trim()?.lowercase()) {
    "low" -> "Low risk" to PillKind.Success
    "medium", "moderate" -> "Medium risk" to PillKind.Warn
    "high", "critical" -> "High risk" to PillKind.Danger
    null, "" -> "—" to PillKind.Neutral
    else -> band.replaceFirstChar { it.uppercase() } to PillKind.Neutral
}

/** Formats a percentage metric, dropping a redundant .0 and adding "%".
 *  Null (not scored) renders as an em dash. */
internal fun formatSlaPct(value: Double?): String {
    if (value == null) return "—"
    val n = if (value % 1.0 == 0.0) value.toLong().toString() else value.toString()
    return "$n%"
}
