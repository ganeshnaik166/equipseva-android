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
import androidx.compose.material.icons.outlined.QueryStats
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
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.founder.FounderMetricRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
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
class FounderMetricListViewModel @Inject constructor(
    savedState: SavedStateHandle,
    private val repo: FounderMetricRepository,
) : ViewModel() {
    val title: String = savedState.get<String>(Routes.FOUNDER_METRICS_ARG_TITLE).orEmpty()
    private val rpc: String = savedState.get<String>(Routes.FOUNDER_METRICS_ARG_RPC).orEmpty()

    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val metrics: List<FounderMetricRepository.Metric> = emptyList(),
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload() }

    fun reload() {
        _state.update { it.copy(loading = it.metrics.isEmpty(), error = null) }
        viewModelScope.launch {
            repo.fetch(rpc)
                .onSuccess { m -> _state.update { it.copy(loading = false, metrics = m) } }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.toUserMessage()) } }
        }
    }
}

/**
 * Generic founder key-value metric dashboard (r1420): renders any founder_*
 * summary RPC that returns (metric, value_text, ...) as a labelled list.
 * Title + RPC name come from the route (chosen from FOUNDER_METRIC_DASHBOARDS).
 * Founder-gated server-side.
 */
@Composable
fun FounderMetricListScreen(
    onBack: () -> Unit,
    viewModel: FounderMetricListViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = viewModel.title.ifBlank { "Metrics" }, onBack = onBack)
            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                state.error != null -> EmptyStateView(
                    icon = Icons.Outlined.QueryStats,
                    title = "Couldn't load metrics",
                    subtitle = state.error,
                    ctaLabel = "Try again",
                    onCta = { viewModel.reload() },
                )
                state.metrics.isEmpty() -> EmptyStateView(
                    icon = Icons.Outlined.QueryStats,
                    title = "No metrics",
                    subtitle = "Nothing to show for this dashboard yet.",
                )
                else -> LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(12.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    items(state.metrics, key = { it.metric }) { m -> MetricRow(m) }
                }
            }
        }
    }
}

@Composable
private fun MetricRow(m: FounderMetricRepository.Metric) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(metricLabel(m.metric), style = EsType.Body, color = SevaInk700, modifier = Modifier.weight(1f))
        Text(
            m.valueText
                ?: m.valueNumeric?.let { formatMetricNumber(it) }
                ?: m.valueNum?.let { formatMetricNumber(it.toDouble()) }
                ?: "—",
            style = EsType.Body.copy(fontWeight = FontWeight.Bold),
            color = SevaInk900,
        )
    }
}

// ---------------------------------------------------------------------
//  Pinned helpers
// ---------------------------------------------------------------------

/** Human label for a metric key: de-snake + capitalise. Already-human labels
 *  (no underscores) just get their first letter capitalised. */
internal fun metricLabel(metric: String): String =
    metric.trim().replace('_', ' ').replaceFirstChar { it.uppercase() }

/** Formats a bare numeric metric, dropping a redundant .0 (12.0 -> "12"). */
internal fun formatMetricNumber(value: Double): String =
    if (value % 1.0 == 0.0) value.toLong().toString() else value.toString()
