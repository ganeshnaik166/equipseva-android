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
        // Round 390 — pull-to-refresh inline indicator.
        val refreshing: Boolean = false,
        val error: String? = null,
        val rows: List<AmcRepository.EngineerAmcVisit> = emptyList(),
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
            amcRepo.listMyAmcVisits()
                .onSuccess { rows -> _state.update { it.copy(loading = false, refreshing = false, rows = rows) } }
                .onFailure { e -> _state.update { it.copy(loading = false, refreshing = false, error = e.toUserMessage()) } }
        }
    }
    fun onPullToRefresh() = reload(initial = false)
}

/**
 * v2.1 PR-D33 — engineer's AMC visits list. Engineers got push when
 * assigned (PR-C5 amc_visit_assigned) but had no list view; this is
 * the unified screen showing every AMC commitment + breach status.
 */
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun EngineerAmcVisitsScreen(
    onBack: () -> Unit,
    onOpenVisit: (visitId: String) -> Unit,
    viewModel: EngineerAmcVisitsViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    // Picks up newly completed / newly scheduled visits on return.
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }
    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(
                title = "AMC visits",
                subtitle = engineerAmcVisitsSubtitle(state.rows.size),
                onBack = onBack,
            )
            // Round 390 — pull-to-refresh.
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
                        icon = Icons.Outlined.Build,
                        title = "Couldn't load",
                        subtitle = state.error,
                        ctaLabel = "Try again",
                        onCta = { viewModel.reload() },
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
                    amcVisitHospitalName(row.hospitalName),
                    color = SevaInk700,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium,
                )
            }
            Pill(
                text = amcVisitStatusLabel(row.status),
                kind = pillForStatus(row.status),
            )
        }
        if (row.visitNumber != null) {
            Text(
                amcVisitNumberLine(row.visitNumber!!, row.equipmentType),
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
                text = amcVisitBreachCountLabel(row.breachCount),
                kind = PillKind.Danger,
            )
        }
    }
}

/**
 * User-facing hospital name on an AMC-visit row. Blank / null
 * collapses to the generic "Hospital" rather than the previous
 * "(unnamed hospital)" placeholder that read as a missing-data bug
 * to engineers. Pin so a regression to a dev-placeholder surfaces.
 */
internal fun amcVisitHospitalName(hospitalName: String?): String =
    hospitalName?.takeIf { it.isNotBlank() } ?: "Hospital"

/**
 * Pretty-print a wire status string for the visit-row Pill: replace
 * underscores with spaces and capitalise the first letter. So
 * "in_progress" → "In progress", "en_route" → "En route".
 *
 * Only the first letter is capitalised — subsequent words stay
 * lowercase. Pin so a refactor to title-case ("In Progress") doesn't
 * desync from the StatusPill copy on the repair-job-detail screen.
 */
internal fun amcVisitStatusLabel(wireStatus: String): String =
    wireStatus.replace('_', ' ').replaceFirstChar { it.uppercase() }

/**
 * Visit-row second-line copy. Composes "Visit #N" with an optional
 * equipment-type suffix.
 *
 *   * visit + equipment → "Visit #3 · Imaging radiology"
 *   * visit only → "Visit #3"
 *
 * Equipment is pretty-printed the same way as the status pill
 * (underscore → space, first-letter capitalise).
 *
 * Middle-dot separator (U+00B7) matches the engineer-card location
 * line for visual consistency.
 */
internal fun amcVisitNumberLine(visitNumber: Int, equipmentType: String?): String {
    val equipmentSuffix = equipmentType
        ?.takeIf { it.isNotBlank() }
        ?.let { " · ${it.replace('_', ' ').replaceFirstChar { c -> c.uppercase() }}" }
        ?: ""
    return "Visit #$visitNumber$equipmentSuffix"
}

/**
 * Singular/plural pluralisation for the AMC-visit SLA-breach-count
 * pill on the engineer-visits row. 1 → "1 open SLA breach", 2+ →
 * "N open SLA breaches".
 *
 * Pinned regression: a refactor to always-interpolated string would
 * surface "1 open SLA breaches" on the most common single-breach
 * case.
 */
internal fun amcVisitBreachCountLabel(breachCount: Int): String {
    val suffix = if (breachCount == 1) "" else "es"
    return "$breachCount open SLA breach$suffix"
}

internal fun pillForStatus(status: String): PillKind = when (status.lowercase()) {
    "completed" -> PillKind.Success
    "in_progress" -> PillKind.Info
    "en_route", "assigned" -> PillKind.Info
    "cancelled" -> PillKind.Default
    else -> PillKind.Warn
}

/**
 * Subtitle on the engineer AMC-visits top bar.
 *
 *   - 0 rows → null (cold-load top bar stays clean)
 *   - 1 row → "1 visit" (singular)
 *   - N rows → "N visits" (plural)
 *
 * Pin singular/plural split — never "1 visits".
 */
internal fun engineerAmcVisitsSubtitle(rowCount: Int): String? = when {
    rowCount <= 0 -> null
    rowCount == 1 -> "1 visit"
    else -> "$rowCount visits"
}
