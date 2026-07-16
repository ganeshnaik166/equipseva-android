package com.equipseva.app.features.hospital

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
import androidx.compose.material.icons.outlined.EventRepeat
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
import com.equipseva.app.core.data.hospital.PmCalendarHeadline
import com.equipseva.app.core.data.hospital.PmCalendarRepository
import com.equipseva.app.core.data.hospital.fleetAssetTitle
import com.equipseva.app.core.data.hospital.formatDaysUntilDue
import com.equipseva.app.core.data.hospital.summarisePmCalendar
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.prettyDate
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen50
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
class PmCalendarViewModel @Inject constructor(
    private val repo: PmCalendarRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val error: String? = null,
        val items: List<PmCalendarRepository.PmScheduleItem> = emptyList(),
        val headline: PmCalendarHeadline = PmCalendarHeadline(0, 0, 0, 0),
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload(initial = true) }

    fun reload(initial: Boolean = false) {
        _state.update {
            it.copy(
                loading = initial || it.items.isEmpty(),
                refreshing = !initial && it.items.isNotEmpty(),
                error = null,
            )
        }
        viewModelScope.launch {
            repo.fetch()
                .onSuccess { rows ->
                    // Server already orders soonest-due (overdue) first.
                    _state.update {
                        it.copy(
                            loading = false,
                            refreshing = false,
                            items = rows,
                            headline = summarisePmCalendar(rows),
                        )
                    }
                }
                .onFailure { e ->
                    _state.update {
                        if (it.items.isEmpty()) it.copy(loading = false, refreshing = false, error = e.toUserMessage())
                        else it.copy(loading = false, refreshing = false)
                    }
                }
        }
    }

    fun onPullToRefresh() = reload(initial = false)
}

/**
 * Read-only preventive-maintenance calendar for hospitals: assets whose next
 * PM is overdue or coming up, so the hospital can book ahead instead of
 * waiting for a breakdown. Reachable from the Profile "Maintenance calendar"
 * row (hospital only). Surfaces hospital_upcoming_pm() (round 507), which had
 * no Android screen before r1398.
 */
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun PmCalendarScreen(
    onBack: () -> Unit,
    viewModel: PmCalendarViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "Maintenance calendar", onBack = onBack)
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
                        icon = Icons.Outlined.EventRepeat,
                        title = "Couldn't load the calendar",
                        subtitle = state.error,
                        ctaLabel = "Try again",
                        onCta = { viewModel.reload() },
                    )
                    state.items.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.EventRepeat,
                        title = "No maintenance due",
                        subtitle = "Nothing's overdue or coming up. Preventive-maintenance schedules build from your completed repair jobs and AMC visits.",
                    )
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(12.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        item(key = "headline") { HeadlineCard(state.headline) }
                        items(state.items, key = { it.id }) { item -> PmRow(item) }
                    }
                }
            }
        }
    }
}

@Composable
private fun HeadlineCard(headline: PmCalendarHeadline) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(SevaGreen50)
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(
            "${headline.total} asset${if (headline.total == 1) "" else "s"} on the calendar",
            color = SevaInk900,
            fontWeight = FontWeight.Bold,
            fontSize = 15.sp,
        )
        Text(
            "${headline.overdue} overdue · ${headline.dueSoon} due this week · ${headline.upcoming} upcoming",
            color = SevaInk700,
            fontSize = 12.sp,
            fontWeight = FontWeight.Medium,
        )
    }
}

@Composable
private fun PmRow(item: PmCalendarRepository.PmScheduleItem) {
    val (pillText, pillKind) = pmStatusPillTextAndKind(item.status)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    fleetAssetTitle(item.equipmentBrand, item.equipmentModel, item.equipmentType),
                    color = SevaInk900,
                    fontWeight = FontWeight.Bold,
                    fontSize = 14.sp,
                )
                item.equipmentSerial?.takeIf { it.isNotBlank() }?.let {
                    Text("SN $it", color = SevaInk500, fontSize = 12.sp)
                }
            }
            Pill(text = pillText, kind = pillKind)
        }
        Text(
            "${formatDaysUntilDue(item.daysUntilDue)} · due ${prettyDate(item.nextPmDueAt)}",
            color = SevaInk700,
            fontSize = 12.sp,
        )
        val cadence = if (item.intervalDays > 0) "Every ${item.intervalDays} days" else null
        val lastServiced = item.lastServiceAt?.takeIf { it.isNotBlank() }?.let { "last serviced ${prettyDate(it)}" }
        listOfNotNull(cadence, lastServiced).takeIf { it.isNotEmpty() }?.let {
            Text(it.joinToString(" · "), color = SevaInk500, fontSize = 11.sp)
        }
    }
}

/**
 * PM status → row pill:
 *   * overdue  → "Overdue"   (Danger)
 *   * due      → "Due now"   (Warn)
 *   * upcoming → "Upcoming"  (Info)
 *   * scheduled/other → "Scheduled" (Neutral, defensive default)
 */
internal fun pmStatusPillTextAndKind(status: String): Pair<String, PillKind> = when (status) {
    "overdue" -> "Overdue" to PillKind.Danger
    "due" -> "Due now" to PillKind.Warn
    "upcoming" -> "Upcoming" to PillKind.Info
    else -> "Scheduled" to PillKind.Neutral
}
