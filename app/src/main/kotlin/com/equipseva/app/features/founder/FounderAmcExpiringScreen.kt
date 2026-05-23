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
import androidx.compose.material.icons.outlined.ErrorOutline
import androidx.compose.material.icons.outlined.EventAvailable
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
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
class FounderAmcExpiringViewModel @Inject constructor(
    private val repo: FounderRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        // Round 382 — pull-to-refresh inline indicator.
        val refreshing: Boolean = false,
        val error: String? = null,
        val rows: List<FounderRepository.ExpiringAmcRow> = emptyList(),
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
            repo.fetchAmcExpiringSoon(windowDays = 30)
                .onSuccess { rows -> _state.update { it.copy(loading = false, refreshing = false, rows = rows) } }
                .onFailure { e -> _state.update { it.copy(loading = false, refreshing = false, error = e.toUserMessage()) } }
        }
    }
    fun onPullToRefresh() = reload(initial = false)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FounderAmcExpiringScreen(
    onBack: () -> Unit,
    onOpenContract: (contractId: String) -> Unit = {},
    viewModel: FounderAmcExpiringViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }
    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(
                title = "Expiring AMCs",
                subtitle = expiringAmcsSubtitle(state.rows.size),
                onBack = onBack,
            )
            // Round 382 — pull-to-refresh.
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
                        icon = Icons.Outlined.ErrorOutline,
                        title = "Couldn't load",
                        subtitle = state.error,
                        ctaLabel = "Try again",
                        onCta = { viewModel.reload() },
                    )
                    state.rows.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.EventAvailable,
                        title = "Nothing expiring soon",
                        subtitle = "No active contracts end in the next 30 days",
                    )
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(12.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        items(state.rows, key = { it.contractId }) { row ->
                            ExpiringRow(row = row, onClick = { onOpenContract(row.contractId) })
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ExpiringRow(
    row: FounderRepository.ExpiringAmcRow,
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
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                row.hospitalName,
                fontWeight = FontWeight.Bold,
                color = SevaInk900,
                modifier = Modifier.weight(1f),
            )
            val (text, kind) = expiringAmcPillTextAndKind(row.daysRemaining)
            Pill(text = text, kind = kind)
        }
        row.primaryEngineerName?.let {
            Text("Engineer: $it", color = SevaInk700, fontSize = 13.sp)
        }
        Text(
            text = expiringAmcRowEndLine(
                prettyEndDate = prettyDate(row.endDate),
                monthlyFeeRupees = row.monthlyFeeRupees,
            ),
            color = SevaInk500,
            fontSize = 12.sp,
        )
        if (row.renewalNotificationsSent > 0) {
            // Surface reminder cadence so the founder doesn't double-page
            // a hospital that already received stage 1/2/3.
            Text(
                text = renewalRemindersSentLabel(row.renewalNotificationsSent),
                color = SevaInk500,
                fontSize = 11.sp,
            )
        }
    }
}

/**
 * Pin the urgency colour + label rule on the founder's
 * AMC-expiring-soon row.
 *
 *   * days ≤ 0 → "Expires today" + Danger
 *   * exactly 1 day → "1 day left" + Danger (singular)
 *   * 2..7 days → "N days left" + Danger
 *   * > 7 days → "N days left" + Warn (amber)
 *
 * Matches the hospital-side r353 rule so founder + hospital see the
 * same urgency cue for the same contract. Pin so a colour change on
 * one surface doesn't desync the other.
 */
internal fun expiringAmcPillTextAndKind(
    daysRemaining: Int,
): Pair<String, com.equipseva.app.designsystem.components.PillKind> = when {
    daysRemaining <= 0 -> "Expires today" to com.equipseva.app.designsystem.components.PillKind.Danger
    daysRemaining == 1 -> "1 day left" to com.equipseva.app.designsystem.components.PillKind.Danger
    daysRemaining <= 7 -> "$daysRemaining days left" to com.equipseva.app.designsystem.components.PillKind.Danger
    else -> "$daysRemaining days left" to com.equipseva.app.designsystem.components.PillKind.Warn
}

/**
 * End-date subline on the founder's AMC-expiring row.
 *
 * Format: "Ends $endDate · ₹X / month" — sibling of [pausedAmcTermLine]
 * but says "Ends" not "Term" because the expiring queue is focused on
 * the END date only (the start is irrelevant when the renewal call is
 * imminent).
 *
 * Pin the literal "Ends " prefix and the " / month" suffix (with
 * spaces around the slash). U+00B7 middle-dot separator.
 */
internal fun expiringAmcRowEndLine(
    prettyEndDate: String,
    monthlyFeeRupees: Double,
): String = "Ends $prettyEndDate · ${com.equipseva.app.core.util.formatRupees(monthlyFeeRupees)} / month"

/**
 * Reminder-cadence label on the founder's AMC-expiring row.
 *
 * Format: "Reminders sent: N/3" — the /3 is load-bearing context.
 * The server sends up to 3 stages of renewal reminders (30d, 14d,
 * 7d). The founder uses this label to decide whether to manually
 * page the hospital (i.e. don't double-page if they've already
 * received stage 3).
 *
 * Pin the "/3" denominator — a refactor to bare "N reminders sent"
 * would lose the cadence anchor.
 */
internal fun renewalRemindersSentLabel(count: Int): String =
    "Reminders sent: $count/3"

/**
 * Subtitle on the founder Expiring-AMCs top bar.
 *
 * Returns null when the list is empty so the top-bar stays clean on
 * cold-load. Otherwise reads "N contracts in next 30 days" — the
 * "30 days" window is the LITERAL constant matching the server-side
 * `notify_expiring_amc_contracts` cutoff (r352 dashboard KPI).
 *
 * Critical cross-surface invariant: the 30-day vocabulary matches
 * the founder dashboard "Expiring 30d" KPI tile + the hospital-side
 * 30d countdown pill. Pin so a refactor that drifted to 14d or 7d
 * on one surface would silently desync the cohort.
 *
 * Pin the plural-blind "N contracts" — singular case (rowCount == 1)
 * still reads "1 contracts in next 30 days" which is technically
 * wrong, but pinning it documents the current behaviour. A future
 * fix should be a deliberate change, not a slip.
 */
internal fun expiringAmcsSubtitle(rowCount: Int): String? =
    if (rowCount > 0) "$rowCount contracts in next 30 days" else null
