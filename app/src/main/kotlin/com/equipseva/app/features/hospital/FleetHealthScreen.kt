package com.equipseva.app.features.hospital

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
import androidx.compose.material.icons.outlined.MonitorHeart
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
import com.equipseva.app.core.data.hospital.FleetHealthHeadline
import com.equipseva.app.core.data.hospital.FleetHealthRepository
import com.equipseva.app.core.data.hospital.fleetAssetTitle
import com.equipseva.app.core.data.hospital.formatDayMetric
import com.equipseva.app.core.data.hospital.formatHourMetric
import com.equipseva.app.core.data.hospital.summariseFleetHealth
import com.equipseva.app.core.data.hospital.uptimeBand
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
import java.util.Locale
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class FleetHealthViewModel @Inject constructor(
    private val repo: FleetHealthRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val error: String? = null,
        val assets: List<FleetHealthRepository.FleetAsset> = emptyList(),
        val headline: FleetHealthHeadline = FleetHealthHeadline(0, 0, 0, 0.0, 0.0),
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload(initial = true) }

    fun reload(initial: Boolean = false) {
        _state.update {
            it.copy(
                loading = initial || it.assets.isEmpty(),
                refreshing = !initial && it.assets.isNotEmpty(),
                error = null,
            )
        }
        viewModelScope.launch {
            repo.fetch()
                .onSuccess { rows ->
                    // Surface the most actionable assets first: replacement
                    // candidates, then lowest uptime.
                    val sorted = rows.sortedWith(
                        compareByDescending<FleetHealthRepository.FleetAsset> { it.replacementCandidate }
                            .thenBy { it.uptimePct },
                    )
                    _state.update {
                        it.copy(
                            loading = false,
                            refreshing = false,
                            assets = sorted,
                            headline = summariseFleetHealth(sorted),
                        )
                    }
                }
                .onFailure { e ->
                    _state.update {
                        if (it.assets.isEmpty()) it.copy(loading = false, refreshing = false, error = e.toUserMessage())
                        else it.copy(loading = false, refreshing = false)
                    }
                }
        }
    }

    fun onPullToRefresh() = reload(initial = false)
}

/**
 * Read-only fleet-reliability board for hospitals: per-asset MTBF / MTTR /
 * uptime over the trailing year, with replacement-candidate flags and the
 * next PM due date. Reachable from the Profile "Fleet health" row (hospital
 * only). Surfaces hospital_fleet_health() (round 508), which had no Android
 * screen before r1396.
 */
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun FleetHealthScreen(
    onBack: () -> Unit,
    onOpenAsset: (serial: String, title: String) -> Unit = { _, _ -> },
    viewModel: FleetHealthViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "Fleet health", onBack = onBack)
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
                        icon = Icons.Outlined.MonitorHeart,
                        title = "Couldn't load fleet health",
                        subtitle = state.error,
                        ctaLabel = "Try again",
                        onCta = { viewModel.reload() },
                    )
                    state.assets.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.MonitorHeart,
                        title = "No equipment data yet",
                        subtitle = "Once you've logged repair jobs against your equipment, per-asset reliability (MTBF, MTTR, uptime) shows up here.",
                    )
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(12.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        item(key = "headline") { HeadlineCard(state.headline) }
                        items(state.assets) { asset -> AssetRow(asset, onOpenAsset) }
                    }
                }
            }
        }
    }
}

@Composable
private fun HeadlineCard(headline: FleetHealthHeadline) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(SevaGreen50)
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                "${headline.totalAssets} asset${if (headline.totalAssets == 1) "" else "s"} tracked",
                color = SevaInk900,
                fontWeight = FontWeight.Bold,
                fontSize = 15.sp,
            )
            Text(
                "%.0f%% avg uptime".format(Locale.ROOT, headline.avgUptimePct),
                color = SevaInk700,
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium,
            )
        }
        Text(
            "${headline.criticalCount} critical · ${headline.replacementCandidates} replacement candidate" +
                if (headline.replacementCandidates == 1) "" else "s",
            color = SevaInk700,
            fontSize = 12.sp,
            fontWeight = FontWeight.Medium,
        )
        Text(
            "${formatHourMetric(headline.totalDowntimeHours)} total downtime in the last 12 months",
            color = SevaInk500,
            fontSize = 11.sp,
        )
    }
}

@Composable
private fun AssetRow(
    asset: FleetHealthRepository.FleetAsset,
    onOpenAsset: (serial: String, title: String) -> Unit,
) {
    val (pillText, pillKind) = uptimePillTextAndKind(asset.uptimePct)
    val title = fleetAssetTitle(asset.equipmentBrand, asset.equipmentModel, asset.equipmentType)
    // Only assets with a serial can drill into their history (asset_history
    // keys on serial); serial-less rows stay non-clickable.
    val serial = asset.equipmentSerial?.takeIf { it.isNotBlank() }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .then(if (serial != null) Modifier.clickable { onOpenAsset(serial, title) } else Modifier)
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    title,
                    color = SevaInk900,
                    fontWeight = FontWeight.Bold,
                    fontSize = 14.sp,
                )
                serial?.let {
                    Text("SN $it", color = SevaInk500, fontSize = 12.sp)
                }
            }
            Pill(text = pillText, kind = pillKind)
        }
        Text(
            "MTBF ${formatDayMetric(asset.mtbfDays)} · MTTR ${formatHourMetric(asset.mttrHours)} · " +
                "${asset.failureCountWindow} failure${if (asset.failureCountWindow == 1) "" else "s"}",
            color = SevaInk700,
            fontSize = 12.sp,
        )
        asset.nextPmDueAt?.takeIf { it.isNotBlank() }?.let {
            Text("Next PM due ${prettyDate(it)}", color = SevaInk500, fontSize = 11.sp)
        }
        if (asset.replacementCandidate) {
            Text("Replacement candidate", color = SevaInk700, fontSize = 11.sp, fontWeight = FontWeight.Medium)
        }
    }
}

/**
 * Uptime → row pill. Reuses [uptimeBand] so the pill and the header's
 * `criticalCount` share one definition of "critical":
 *   * healthy  → "Healthy" (Success)
 *   * watch    → "Watch"   (Warn)
 *   * critical → "Critical" (Danger)
 */
internal fun uptimePillTextAndKind(uptimePct: Double): Pair<String, PillKind> =
    when (uptimeBand(uptimePct)) {
        "healthy" -> "Healthy" to PillKind.Success
        "watch" -> "Watch" to PillKind.Warn
        else -> "Critical" to PillKind.Danger
    }
