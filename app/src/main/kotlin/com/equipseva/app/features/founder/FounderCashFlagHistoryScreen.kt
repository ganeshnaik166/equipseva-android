package com.equipseva.app.features.founder

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
import androidx.compose.material.icons.outlined.ErrorOutline
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
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
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
import com.equipseva.app.navigation.Routes
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class FounderCashFlagHistoryViewModel @Inject constructor(
    private val repo: FounderRepository,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {
    private val engineerId: String =
        savedStateHandle.get<String>(Routes.FOUNDER_CASH_FLAG_HISTORY_ARG_ENGINEER_ID).orEmpty()

    data class UiState(
        val loading: Boolean = true,
        // Round 410 — pull-to-refresh inline indicator distinct from cold-load.
        val refreshing: Boolean = false,
        val error: String? = null,
        val rows: List<FounderRepository.CashFlagHistoryRow> = emptyList(),
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload(initial = true) }

    fun onPullToRefresh() = reload(initial = false)

    fun reload(initial: Boolean = false) {
        if (engineerId.isBlank()) {
            _state.update { it.copy(loading = false, refreshing = false, error = "Missing engineer id") }
            return
        }
        _state.update {
            it.copy(
                loading = initial || it.rows.isEmpty(),
                refreshing = !initial && it.rows.isNotEmpty(),
                error = null,
            )
        }
        viewModelScope.launch {
            repo.fetchEngineerCashFlagHistory(engineerId)
                .onSuccess { rows -> _state.update { it.copy(loading = false, refreshing = false, rows = rows) } }
                .onFailure { e -> _state.update { it.copy(loading = false, refreshing = false, error = e.toUserMessage()) } }
        }
    }
}

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun FounderCashFlagHistoryScreen(
    onBack: () -> Unit,
    viewModel: FounderCashFlagHistoryViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }
    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(
                title = "Cash-flag history",
                subtitle = cashFlagHistorySubtitle(state.rows.size),
                onBack = onBack,
            )
            // Round 410 — pull-to-refresh. Matches r378-r400 pattern.
            androidx.compose.material3.pulltorefresh.PullToRefreshBox(
                isRefreshing = state.refreshing,
                onRefresh = viewModel::onPullToRefresh,
                modifier = Modifier.fillMaxSize(),
            ) {
                when {
                    state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                    state.error != null && state.rows.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.ErrorOutline,
                        title = "Couldn't load",
                        subtitle = state.error,
                        ctaLabel = "Try again",
                        onCta = { viewModel.reload() },
                    )
                    state.rows.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.Inbox,
                        title = "No history",
                        subtitle = "No cash-survey responses on this engineer in the last 365 days.",
                    )
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(12.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        items(state.rows, key = { it.responseId }) { row -> CashFlagRow(row) }
                    }
                }
            }
        }
    }
}

@Composable
private fun CashFlagRow(row: FounderRepository.CashFlagHistoryRow) {
    val (pillText, pillKind) = cashFlagResponsePillTextAndKind(row.response)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = cashFlagRowTitle(row.jobNumber, row.repairJobId),
                    color = SevaInk900,
                    fontWeight = FontWeight.Bold,
                    fontSize = 14.sp,
                )
                Text(
                    text = cashFlagRowHospitalLabel(row.hospitalName),
                    color = SevaInk700,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium,
                )
            }
            Pill(text = pillText, kind = pillKind)
        }
        row.respondedAt?.let {
            Text("Responded: ${cashFlagRespondedAtLabel(it)}", color = SevaInk500, fontSize = 11.sp)
        }
        row.completedAt?.let {
            Text("Job completed: ${prettyDate(it)}", color = SevaInk500, fontSize = 11.sp)
        }
    }
}

/**
 * Pill text + colour kind for a cash-flag-history row.
 *
 * Wire CHECK constraint enum: `asked_cash`, `no_cash`, `declined`.
 *
 * Critical regression target:
 *   - `asked_cash` → "Cash asked" + Danger (the load-bearing
 *     flag — engineer admitted to soliciting cash; founder uses
 *     this to make the suspension call).
 *   - `no_cash` → "No cash" + Success (clean response).
 *   - `declined` → "Declined" + Default (engineer didn't answer
 *     the survey; neutral colour, not Warn — pin so a refactor
 *     that escalated this to Warn surfaces).
 *   - unknown → raw wire string + Default (forward-compat for a
 *     new CHECK enum value).
 *
 * Pin the EXACT wire strings (`asked_cash`, not `asked-cash` or
 * `askedCash`) so a server-side rename surfaces here rather than
 * silently downgrading every row to the unknown branch.
 */
internal fun cashFlagResponsePillTextAndKind(response: String): Pair<String, PillKind> =
    when (response) {
        "asked_cash" -> "Cash asked" to PillKind.Danger
        "no_cash"    -> "No cash" to PillKind.Success
        "declined"   -> "Declined" to PillKind.Default
        else         -> response to PillKind.Default
    }

/**
 * Title for a cash-flag-history row: prefer the server jobNumber,
 * fall back to "RPR-${first 6 chars of repairJobId}". Sibling of
 * the other founder queue row titles (escrow / parts / resolved /
 * outliers).
 */
internal fun cashFlagRowTitle(jobNumber: String?, repairJobId: String): String =
    jobNumber ?: "RPR-${repairJobId.take(6)}"

/**
 * Hospital-name fallback for a cash-flag-history row. Mirrors the
 * other founder queues — null/blank surfaces "Hospital".
 */
internal fun cashFlagRowHospitalLabel(hospitalName: String?): String =
    hospitalName?.takeIf { it.isNotBlank() } ?: "Hospital"

/**
 * Responded-at timestamp label on the cash-flag-history row.
 *
 * Truncates to the first 16 chars of the ISO-8601 timestamp (drops
 * seconds + timezone, leaving "YYYY-MM-DDTHH:MM") and swaps the
 * ISO 'T' separator for a space → "YYYY-MM-DD HH:MM".
 *
 * Pin take(16) — load-bearing because longer ISO strings ("…:30Z",
 * "…:30+05:30") get visually noisy in the row's tight 11sp subline.
 * A drift to take(19) would leak the seconds; take(10) would lose
 * the time-of-day. Both would change how the founder cross-references
 * timestamps with audit logs.
 *
 * Pin the T→space swap — pin so a refactor that kept the raw ISO
 * shape doesn't slip in (the 'T' is a programmer convention, not
 * something the founder should see in the UI).
 */
internal fun cashFlagRespondedAtLabel(rawIso: String): String =
    rawIso.take(16).replace('T', ' ')

/**
 * Subtitle on the founder Cash-Flag History top bar.
 *
 * Returns null on empty list. Otherwise reads "N responses · last 365d".
 *
 * Critical pin: the "365d" rolling window — distinct from the 30d
 * windows on other founder queues (escrow resolved, AMC expiring).
 * Cash-flag history queries the full year because suspensions stay
 * relevant beyond the immediate triage window.
 *
 * Pin "responses" noun — distinct from "flags" (which counts
 * server-side cash_flags rows). A response is a survey reply
 * (asked_cash / no_cash / declined); the cash-flag suspension
 * trigger counts asked_cash responses specifically.
 */
internal fun cashFlagHistorySubtitle(rowCount: Int): String? =
    if (rowCount > 0) "$rowCount responses · last 365d" else null
