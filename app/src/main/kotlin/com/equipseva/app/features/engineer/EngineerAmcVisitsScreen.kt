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
import androidx.compose.material.icons.outlined.Build
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
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.amc.AmcRepository
import com.equipseva.app.core.network.toUserMessage
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
class EngineerAmcVisitsViewModel @Inject constructor(
    private val amcRepo: AmcRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val rows: List<AmcRepository.EngineerAmcVisit> = emptyList(),
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload() }

    fun reload() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            amcRepo.listMyAmcVisits()
                .onSuccess { rows -> _state.update { it.copy(loading = false, rows = rows) } }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.toUserMessage()) } }
        }
    }
}

/**
 * v2.1 PR-D33 — engineer's AMC visits list. Engineers got push when
 * assigned (PR-C5 amc_visit_assigned) but had no list view; this is
 * the unified screen showing every AMC commitment + breach status.
 */
@Composable
fun EngineerAmcVisitsScreen(
    onBack: () -> Unit,
    onOpenVisit: (visitId: String) -> Unit,
    viewModel: EngineerAmcVisitsViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(
                title = "AMC visits",
                subtitle = state.rows.size.takeIf { it > 0 }?.let {
                    "$it ${if (it == 1) "visit" else "visits"}"
                },
                onBack = onBack,
            )
            Box(modifier = Modifier.fillMaxSize()) {
                when {
                    state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                    state.error != null -> EmptyStateView(
                        icon = Icons.Outlined.Build,
                        title = "Couldn't load",
                        subtitle = state.error,
                    )
                    state.rows.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.Build,
                        title = "No AMC visits yet",
                        subtitle = "AMC visits land here once a hospital adds you to a maintenance contract.",
                    )
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(12.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        items(state.rows, key = { it.visitId }) { row ->
                            VisitRow(row = row, onClick = { onOpenVisit(row.visitId) })
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun VisitRow(
    row: AmcRepository.EngineerAmcVisit,
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
                    row.jobNumber ?: "AMC visit",
                    color = SevaInk900,
                    fontWeight = FontWeight.Bold,
                    fontSize = 14.sp,
                )
                Text(
                    // The "(unnamed hospital)" fallback read as a
                    // missing-data bug to engineers seeing the row.
                    // Mirrors round 37: collapse blank/null names to
                    // the row category — "Hospital" — instead of a
                    // dev-placeholder string.
                    row.hospitalName?.takeIf { it.isNotBlank() } ?: "Hospital",
                    color = SevaInk700,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium,
                )
            }
            Pill(
                text = row.status.replace('_', ' ').replaceFirstChar { it.uppercase() },
                kind = pillForStatus(row.status),
            )
        }
        if (row.visitNumber != null) {
            val equipmentSuffix = row.equipmentType
                ?.let { " · ${it.replace('_', ' ').replaceFirstChar { c -> c.uppercase() }}" }
                ?: ""
            Text(
                "Visit #${row.visitNumber}$equipmentSuffix",
                color = SevaInk500,
                fontSize = 11.sp,
            )
        }
        row.scheduledDate?.let {
            Text("Scheduled: ${prettyDate(it)}", color = SevaInk500, fontSize = 11.sp)
        }
        row.completedAt?.let {
            Text("Completed: ${prettyDate(it)}", color = SevaInk500, fontSize = 11.sp)
        }
        if (row.breachCount > 0) {
            Pill(
                text = "${row.breachCount} open SLA breach${if (row.breachCount == 1) "" else "es"}",
                kind = PillKind.Danger,
            )
        }
    }
}

private fun pillForStatus(status: String): PillKind = when (status.lowercase()) {
    "completed" -> PillKind.Success
    "in_progress" -> PillKind.Info
    "en_route", "assigned" -> PillKind.Info
    "cancelled" -> PillKind.Default
    else -> PillKind.Warn
}
