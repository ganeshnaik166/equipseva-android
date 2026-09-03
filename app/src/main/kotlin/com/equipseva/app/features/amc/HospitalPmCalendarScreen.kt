package com.equipseva.app.features.amc

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
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.R
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk600
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * Round 3770 — hospital-facing screen for the Predictive PM Calendar
 * backend (round507, v0.4 Phase 4 #4). The backend has run standalone
 * for months (daily cron forward-projects next-due dates per piece of
 * equipment from signed DSRs) but no client ever read it — this is the
 * first caller of `hospital_upcoming_pm` / `recompute_pm_schedule`.
 */
@HiltViewModel
class HospitalPmCalendarViewModel @Inject constructor(
    private val repo: HospitalPmCalendarRepository,
    private val auth: AuthRepository,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val error: String? = null,
        val items: List<HospitalPmCalendarRepository.PmScheduleItem> = emptyList(),
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init {
        refresh(initial = true)
    }

    fun onPullToRefresh() = refresh(initial = false)

    fun refresh(initial: Boolean = false) {
        _state.update {
            it.copy(
                loading = initial || it.items.isEmpty(),
                refreshing = !initial && it.items.isNotEmpty(),
                error = null,
            )
        }
        viewModelScope.launch {
            val userId = auth.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .firstOrNull()
                ?.userId
            if (userId == null) {
                _state.update { UiState(loading = false, refreshing = false, items = emptyList()) }
                return@launch
            }

            // Best-effort — a failed recompute must not block reading
            // whatever schedule already exists from the last cron tick.
            repo.recomputeSchedule(userId)

            repo.fetchUpcoming()
                .onSuccess { list ->
                    _state.update { UiState(loading = false, refreshing = false, items = list) }
                }
                .onFailure { e ->
                    _state.update {
                        UiState(
                            loading = false,
                            refreshing = false,
                            error = e.toUserMessage("Could not load maintenance calendar."),
                        )
                    }
                }
        }
    }
}

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun HospitalPmCalendarScreen(
    onBack: () -> Unit,
    viewModel: HospitalPmCalendarViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Box(Modifier.fillMaxSize().background(PaperDefault)) {
        Column(Modifier.fillMaxSize()) {
            EsTopBar(title = stringResource(R.string.hospital_pm_calendar_title), onBack = onBack)

            androidx.compose.material3.pulltorefresh.PullToRefreshBox(
                isRefreshing = state.refreshing,
                onRefresh = viewModel::onPullToRefresh,
                modifier = Modifier.fillMaxSize(),
            ) {
                when {
                    state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }

                    state.error != null && state.items.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.CalendarMonth,
                        title = stringResource(R.string.hospital_pm_calendar_couldnt_load),
                        subtitle = state.error,
                        ctaLabel = stringResource(R.string.hospital_pm_calendar_try_again),
                        onCta = { viewModel.refresh() },
                    )

                    state.items.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.CalendarMonth,
                        title = stringResource(R.string.hospital_pm_calendar_empty_title),
                        subtitle = stringResource(R.string.hospital_pm_calendar_empty_body),
                    )

                    else -> {
                        val grouped = groupPmItemsByStatus(state.items)
                        LazyColumn(
                            modifier = Modifier.fillMaxSize(),
                            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
                            verticalArrangement = Arrangement.spacedBy(10.dp),
                        ) {
                            grouped.forEach { (status, rows) ->
                                item(key = "_header_$status") {
                                    Text(
                                        pmSectionHeader(status, rows.size),
                                        style = EsType.H5,
                                        color = SevaInk900,
                                    )
                                }
                                items(rows, key = { it.id }) { row -> PmScheduleCard(row) }
                            }
                            item(key = "_footer_note") {
                                Column {
                                    Spacer(Modifier.height(4.dp))
                                    Text(
                                        stringResource(R.string.hospital_pm_calendar_footer_note),
                                        style = EsType.BodySm,
                                        color = SevaInk500,
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun PmScheduleCard(row: HospitalPmCalendarRepository.PmScheduleItem) {
    val (label, kind) = pmStatusLabelAndKind(row.status)
    Box(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(14.dp),
    ) {
        Column {
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    RepairEquipmentCategory.fromKey(row.equipmentType).displayName,
                    style = EsType.H5.copy(fontWeight = FontWeight.SemiBold),
                    color = SevaInk900,
                )
                Pill(text = label, kind = kind)
            }
            val subtitle = pmEquipmentSubtitle(row)
            if (subtitle.isNotBlank()) {
                Spacer(Modifier.height(2.dp))
                Text(subtitle, style = EsType.BodySm, color = SevaInk500)
            }
            Spacer(Modifier.height(10.dp))
            PmLine(
                label = stringResource(R.string.hospital_pm_calendar_last_serviced),
                value = row.lastServiceAt?.let { prettyDate(it) }
                    ?: stringResource(R.string.hospital_pm_calendar_never_serviced),
            )
            PmLine(
                label = stringResource(R.string.hospital_pm_calendar_next_due),
                value = prettyDate(row.nextPmDueAt),
            )
            PmLine(
                label = stringResource(R.string.hospital_pm_calendar_cadence),
                value = stringResource(R.string.hospital_pm_calendar_every_n_days, row.intervalDays),
            )
            Spacer(Modifier.height(6.dp))
            Text(
                pmDueInText(row.status, row.daysUntilDue),
                style = EsType.BodySm.copy(fontWeight = FontWeight.SemiBold),
                color = if (row.status == "overdue") SevaDanger500 else SevaInk700,
            )
        }
    }
}

@Composable
private fun PmLine(label: String, value: String) {
    Row(
        Modifier.fillMaxWidth().padding(vertical = 2.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(label, style = EsType.BodySm, color = SevaInk600)
        Text(value, style = EsType.BodySm.copy(fontWeight = FontWeight.SemiBold), color = SevaInk900)
    }
}

/**
 * Group + order the hospital's upcoming-PM rows: overdue first (most
 * urgent), then due, upcoming, scheduled. Any status outside that
 * known set (shouldn't happen — the server only ever emits these four
 * for `hospital_upcoming_pm`, which excludes completed/cancelled) is
 * still appended rather than silently dropped.
 */
internal fun groupPmItemsByStatus(
    items: List<HospitalPmCalendarRepository.PmScheduleItem>,
): List<Pair<String, List<HospitalPmCalendarRepository.PmScheduleItem>>> {
    val order = listOf("overdue", "due", "upcoming", "scheduled")
    val knownAndExtra = order + items.map { it.status }.distinct().filterNot { it in order }
    return knownAndExtra.distinct().mapNotNull { status ->
        items.filter { it.status == status }.takeIf { it.isNotEmpty() }?.let { status to it }
    }
}

internal fun pmSectionHeader(status: String, count: Int): String = when (status) {
    "overdue" -> "Overdue ($count)"
    "due" -> "Due this week ($count)"
    "upcoming" -> "Due this month ($count)"
    "scheduled" -> "Scheduled ($count)"
    else -> "${status.replaceFirstChar { it.uppercase() }} ($count)"
}

internal fun pmStatusLabelAndKind(status: String): Pair<String, PillKind> = when (status) {
    "overdue" -> "Overdue" to PillKind.Danger
    "due" -> "Due soon" to PillKind.Warn
    "upcoming" -> "Upcoming" to PillKind.Info
    "scheduled" -> "Scheduled" to PillKind.Neutral
    else -> status.replaceFirstChar { it.uppercase() } to PillKind.Neutral
}

/**
 * "Overdue by N days" / "Due today" / "Due in N days" — rounds the
 * server's fractional `days_until_due` (EXTRACT EPOCH / 86400) to the
 * nearest whole day for display.
 *
 * Driven by [status] first, not just the sign of [daysUntilDue]: a row
 * that crossed into overdue moments ago rounds to n=0, which would
 * otherwise misreport as "Due today" while its pill still says
 * "Overdue" — status is the server's authoritative signal (it flips at
 * `next_pm_due_at < now()`, not at a rounded day boundary), so an
 * overdue row is always phrased as overdue (floor of at least 1 day).
 */
internal fun pmDueInText(status: String, daysUntilDue: Double): String {
    val n = kotlin.math.round(daysUntilDue).toLong()
    return if (status == "overdue" || n < 0L) {
        val overdueBy = maxOf(-n, 1L)
        if (overdueBy == 1L) "Overdue by 1 day" else "Overdue by $overdueBy days"
    } else when (n) {
        0L -> "Due today"
        1L -> "Due in 1 day"
        else -> "Due in $n days"
    }
}

internal fun pmEquipmentSubtitle(row: HospitalPmCalendarRepository.PmScheduleItem): String {
    val parts = listOfNotNull(
        row.equipmentBrand?.takeIf { it.isNotBlank() },
        row.equipmentModel?.takeIf { it.isNotBlank() },
    )
    val base = parts.joinToString(" · ")
    val serial = row.equipmentSerial?.takeIf { it.isNotBlank() }
    return when {
        base.isBlank() && serial == null -> ""
        base.isBlank() -> "S/N $serial"
        serial == null -> base
        else -> "$base · S/N $serial"
    }
}
