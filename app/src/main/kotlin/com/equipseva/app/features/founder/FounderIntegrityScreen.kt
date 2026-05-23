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
import androidx.compose.material.icons.outlined.Security
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
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.Paper2
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
class FounderIntegrityViewModel @Inject constructor(
    savedStateHandle: androidx.lifecycle.SavedStateHandle,
    private val repo: FounderRepository,
) : ViewModel() {
    // Round 360 — optional buyer filter from r351 Payments-row tap.
    private val filterUserId: String? =
        savedStateHandle[com.equipseva.app.navigation.Routes.FOUNDER_INTEGRITY_ARG_USER]
    private val filterUserName: String? =
        savedStateHandle[com.equipseva.app.navigation.Routes.FOUNDER_INTEGRITY_ARG_NAME]

    data class UiState(
        val loading: Boolean = true,
        // Round 381 — pull-to-refresh inline indicator.
        val refreshing: Boolean = false,
        val error: String? = null,
        val rows: List<FounderRepository.IntegrityFlag> = emptyList(),
        val filterUserId: String? = null,
        val filterUserName: String? = null,
    )
    private val _state = MutableStateFlow(
        UiState(filterUserId = filterUserId, filterUserName = filterUserName)
    )
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
            repo.fetchIntegrityFlags(limit = 100)
                .onSuccess { rows ->
                    // Server returns the most recent 100 events globally. With
                    // a filter we narrow client-side — at the 100-row window
                    // a single buyer's history is almost always present in
                    // full, and a server-side filter would need a new RPC
                    // for a small payoff.
                    val visible = if (filterUserId.isNullOrBlank()) rows
                    else rows.filter { it.userId == filterUserId }
                    _state.update { it.copy(loading = false, refreshing = false, rows = visible) }
                }
                .onFailure { e -> _state.update { it.copy(loading = false, refreshing = false, error = e.toUserMessage()) } }
        }
    }

    fun onPullToRefresh() = reload(initial = false)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FounderIntegrityScreen(
    onBack: () -> Unit,
    viewModel: FounderIntegrityViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }
    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(
                title = "Integrity flags",
                subtitle = when {
                    // Round 360 — when arrived via Payments-row tap-through,
                    // show whose history we're filtered to. Buyer name first,
                    // event count second.
                    !state.filterUserName.isNullOrBlank() ->
                        "${state.filterUserName} · ${state.rows.size} events"
                    state.filterUserId != null ->
                        "Filtered · ${state.rows.size} events"
                    state.rows.isNotEmpty() -> "${state.rows.size} events"
                    else -> null
                },
                onBack = onBack,
            )
            // Round 381 — pull-to-refresh. Matches r378-r380 pattern.
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
                        icon = Icons.Outlined.Security,
                        title = "No integrity events yet",
                        subtitle = "Play Integrity attestations appear here",
                    )
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(12.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        items(state.rows, key = { it.checkId }) { row ->
                            IntegrityRow(row = row)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun IntegrityRow(row: FounderRepository.IntegrityFlag) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(androidx.compose.ui.graphics.Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            PassFailPill(pass = row.pass)
            Text(
                text = integrityActionLabel(row.action),
                color = SevaInk900,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.weight(1f),
            )
            row.createdAt?.let { ts ->
                Text(
                    text = integrityRowTimestampLabel(ts, com.equipseva.app.core.util.relativeLabel(ts)),
                    color = SevaInk500,
                    fontSize = 11.sp,
                )
            }
        }
        row.userEmail?.let {
            Text(it, color = SevaInk700, fontSize = 13.sp)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            VerdictChip(label = "device", value = row.deviceVerdict)
            VerdictChip(label = "app", value = row.appVerdict)
            row.licensingVerdict?.let { VerdictChip(label = "lic", value = it) }
        }
    }
}

@Composable
private fun PassFailPill(pass: Boolean) {
    val (text, kind) = integrityPassFailPillTextAndKind(pass)
    Pill(text = text, kind = kind)
}

@Composable
private fun VerdictChip(label: String, value: String?) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(8.dp))
            .background(Paper2)
            .border(1.dp, BorderDefault, RoundedCornerShape(8.dp))
            .padding(horizontal = 8.dp, vertical = 3.dp),
    ) {
        Text(
            text = verdictChipText(label, value),
            color = SevaInk700,
            fontSize = 11.sp,
            fontWeight = FontWeight.Medium,
        )
    }
}

/**
 * Action-name label on the integrity-flag row. Wire value is a
 * server-side enum (`launch`, `request_signed`, …); null/missing
 * surfaces as "unknown action" so a backfill row stays addressable.
 *
 * Pin literal "unknown action" — a refactor to "Unknown" (capitalised)
 * would clash with the surrounding lowercase action codes that flow
 * inline as continuous prose.
 */
internal fun integrityActionLabel(action: String?): String =
    action ?: "unknown action"

/**
 * Timestamp label on the integrity-flag row. Prefer the
 * locale-friendly relative label ("2 hours ago"), fall back to the
 * raw ISO date prefix (first 10 chars = "YYYY-MM-DD") when the
 * relative formatter returns null (unparseable timestamp).
 *
 * Pin take(10) — load-bearing because the integrity stream stores
 * ISO-8601 with timezone suffix; truncating to 10 strips time + tz
 * and gives the founder a stable date key for log cross-referencing.
 */
internal fun integrityRowTimestampLabel(rawIso: String, relativeLabel: String?): String =
    relativeLabel ?: rawIso.take(10)

/**
 * Chip text on the integrity-flag verdict chip: "$label: $value".
 *
 * Critical region: blank/null value surfaces as U+2014 em-dash (NOT
 * "N/A", "unknown", or empty). The chip is visually tight and the
 * em-dash is the project-wide convention for missing data — pin so a
 * refactor that introduced a "N/A" string would clash with the
 * sibling repair-job-detail [textOrDash] convention.
 */
internal fun verdictChipText(label: String, value: String?): String {
    val v = value?.takeIf { it.isNotBlank() } ?: "—"
    return "$label: $v"
}

/**
 * Pass/fail pill text + colour kind on the integrity-flag row.
 * Pin the all-caps "PASS" / "FAIL" — these are not full words; they
 * intentionally mirror the server's compact log shape so the founder
 * can grep logs and screen consistently.
 */
internal fun integrityPassFailPillTextAndKind(pass: Boolean): Pair<String, PillKind> =
    if (pass) "PASS" to PillKind.Success else "FAIL" to PillKind.Danger

