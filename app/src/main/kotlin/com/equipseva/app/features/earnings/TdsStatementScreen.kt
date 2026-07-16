package com.equipseva.app.features.earnings

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
import androidx.compose.material.icons.outlined.Percent
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
import com.equipseva.app.core.data.payouts.TdsFyTotal
import com.equipseva.app.core.data.payouts.TdsSummaryRepository
import com.equipseva.app.core.data.payouts.rollUpTdsAcrossQuarters
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
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
class TdsStatementViewModel @Inject constructor(
    private val repo: TdsSummaryRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val error: String? = null,
        val quarters: List<TdsSummaryRepository.TdsQuarterRow> = emptyList(),
        val total: TdsFyTotal? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload(initial = true) }

    fun reload(initial: Boolean = false) {
        _state.update {
            it.copy(
                loading = initial || it.quarters.isEmpty(),
                refreshing = !initial && it.quarters.isNotEmpty(),
                error = null,
            )
        }
        viewModelScope.launch {
            repo.fetchTdsSummary()
                .onSuccess { rows ->
                    _state.update {
                        it.copy(
                            loading = false,
                            refreshing = false,
                            quarters = rows,
                            total = rollUpTdsAcrossQuarters(rows),
                        )
                    }
                }
                // r1452 — keep loaded quarters on a transient refresh failure.
                .onFailure { e ->
                    _state.update {
                        if (it.quarters.isEmpty()) it.copy(loading = false, refreshing = false, error = e.toUserMessage())
                        else it.copy(loading = false, refreshing = false)
                    }
                }
        }
    }

    fun onPullToRefresh() = reload(initial = false)
}

/**
 * Engineer TDS (194-O) statement for the current financial year: an FY hero
 * (gross / TDS withheld / net + effective rate) over per-quarter rows.
 * Read-only, reachable from the Earnings screen.
 */
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun TdsStatementScreen(
    onBack: () -> Unit,
    viewModel: TdsStatementViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "Tax deducted (TDS)", onBack = onBack)
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
                        icon = Icons.Outlined.Percent,
                        title = "Couldn't load TDS",
                        subtitle = state.error,
                        ctaLabel = "Try again",
                        onCta = { viewModel.reload() },
                    )
                    state.quarters.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.Percent,
                        title = "No TDS this year",
                        subtitle = "TDS (section 194-O) withheld from your payouts appears here, by quarter, for the current financial year.",
                    )
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(12.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        state.total?.let { total ->
                            item("tds_hero") { TdsHeroCard(total) }
                        }
                        items(state.quarters, key = { it.fyQuarter }) { q -> QuarterRow(q) }
                    }
                }
            }
        }
    }
}

@Composable
private fun TdsHeroCard(total: TdsFyTotal) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(SevaGreen50)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(total.fiscalYear, color = SevaInk700, fontWeight = FontWeight.Medium, fontSize = 13.sp)
        Text(formatRupees(total.tdsRupees), color = SevaGreen700, fontWeight = FontWeight.Bold, fontSize = 26.sp)
        Text("TDS withheld this financial year", color = SevaInk500, fontSize = 12.sp)
        Spacer(Modifier.height(4.dp))
        Text(
            "Gross ${formatRupees(total.grossRupees)} · Net paid ${formatRupees(total.netPayableRupees)}",
            color = SevaInk700,
            fontSize = 12.sp,
            fontWeight = FontWeight.Medium,
        )
        Text(
            "Effective rate ${String.format(java.util.Locale.ROOT, "%.1f%%", total.effectiveTdsRatePct)} · ${total.deductionCount} deductions",
            color = SevaInk500,
            fontSize = 11.sp,
        )
    }
}

@Composable
private fun QuarterRow(q: TdsSummaryRepository.TdsQuarterRow) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(q.fyQuarter, color = SevaInk900, fontWeight = FontWeight.Bold, fontSize = 14.sp)
            Text("TDS ${formatRupees(q.tdsRupees)}", color = SevaGreen700, fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
        }
        Text(
            "Gross ${formatRupees(q.grossRupees)} · Net ${formatRupees(q.netPayableRupees)} · ${q.deductionCount} payouts",
            color = SevaInk500,
            fontSize = 12.sp,
        )
    }
}
