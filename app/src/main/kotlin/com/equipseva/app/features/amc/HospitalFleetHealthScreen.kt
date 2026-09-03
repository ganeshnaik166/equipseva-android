package com.equipseva.app.features.amc

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.material.icons.outlined.Build
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
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk600
import com.equipseva.app.designsystem.theme.SevaInk900
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * Round 3771 — hospital-facing Equipment Fleet Health screen for the
 * round508 backend (v0.4 Phase 4 "Equipment Fleet Console + MTBF/MTTR
 * Dashboard"). First client of `hospital_fleet_health` / `asset_history`
 * — see [HospitalFleetHealthRepository].
 */
@HiltViewModel
class HospitalFleetHealthViewModel @Inject constructor(
    private val repo: HospitalFleetHealthRepository,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val error: String? = null,
        val items: List<HospitalFleetHealthRepository.FleetHealthItem> = emptyList(),
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
            repo.fetchFleetHealth()
                .onSuccess { list ->
                    _state.update { UiState(loading = false, refreshing = false, items = list) }
                }
                .onFailure { e ->
                    _state.update {
                        UiState(
                            loading = false,
                            refreshing = false,
                            error = e.toUserMessage("Could not load fleet health."),
                        )
                    }
                }
        }
    }
}

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun HospitalFleetHealthScreen(
    onBack: () -> Unit,
    onOpenAsset: (String) -> Unit,
    viewModel: HospitalFleetHealthViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Box(Modifier.fillMaxSize().background(PaperDefault)) {
        Column(Modifier.fillMaxSize()) {
            EsTopBar(title = stringResource(R.string.hospital_fleet_health_title), onBack = onBack)

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
                        icon = Icons.Outlined.Build,
                        title = stringResource(R.string.hospital_fleet_health_couldnt_load),
                        subtitle = state.error,
                        ctaLabel = stringResource(R.string.hospital_fleet_health_try_again),
                        onCta = { viewModel.refresh() },
                    )

                    state.items.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.Build,
                        title = stringResource(R.string.hospital_fleet_health_empty_title),
                        subtitle = stringResource(R.string.hospital_fleet_health_empty_body),
                    )

                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        items(state.items, key = { fleetItemKey(it) }) { item ->
                            FleetHealthCard(
                                item = item,
                                onClick = if (!item.equipmentSerial.isNullOrBlank()) {
                                    { onOpenAsset(item.equipmentSerial) }
                                } else {
                                    null
                                },
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun FleetHealthCard(
    item: HospitalFleetHealthRepository.FleetHealthItem,
    onClick: (() -> Unit)?,
) {
    Box(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .let { if (onClick != null) it.clickable(onClick = onClick) else it }
            .padding(14.dp),
    ) {
        Column {
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    RepairEquipmentCategory.fromKey(item.equipmentType).displayName,
                    style = EsType.H5.copy(fontWeight = FontWeight.SemiBold),
                    color = SevaInk900,
                )
                if (item.replacementCandidate) {
                    Pill(
                        text = stringResource(R.string.hospital_fleet_health_replacement_candidate),
                        kind = PillKind.Danger,
                    )
                }
            }
            val subtitle = fleetEquipmentSubtitle(item)
            if (subtitle.isNotBlank()) {
                Spacer(Modifier.height(2.dp))
                Text(subtitle, style = EsType.BodySm, color = SevaInk500)
            }
            Spacer(Modifier.height(10.dp))
            FleetLine(
                stringResource(R.string.hospital_fleet_health_failures_in_window),
                item.failureCountWindow.toString(),
            )
            FleetLine(
                stringResource(R.string.hospital_fleet_health_mtbf),
                item.mtbfDays?.let { stringResource(R.string.hospital_fleet_health_n_days, it.toInt()) }
                    ?: stringResource(R.string.hospital_fleet_health_not_enough_data),
            )
            FleetLine(
                stringResource(R.string.hospital_fleet_health_mttr),
                item.mttrHours?.let { stringResource(R.string.hospital_fleet_health_n_hours, it.toInt()) }
                    ?: stringResource(R.string.hospital_fleet_health_not_enough_data),
            )
            FleetLine(
                stringResource(R.string.hospital_fleet_health_uptime),
                "${item.uptimePct}%",
            )
            if (item.lastFailureAt != null) {
                FleetLine(
                    stringResource(R.string.hospital_fleet_health_last_failure),
                    prettyDate(item.lastFailureAt),
                )
            }
            if (item.nextPmDueAt != null) {
                FleetLine(
                    stringResource(R.string.hospital_fleet_health_next_pm_due),
                    prettyDate(item.nextPmDueAt),
                )
            }
            if (onClick != null) {
                Spacer(Modifier.height(6.dp))
                Text(
                    stringResource(R.string.hospital_fleet_health_view_history),
                    style = EsType.BodySm.copy(fontWeight = FontWeight.SemiBold),
                    color = SevaInk600,
                )
            }
        }
    }
}

@Composable
private fun FleetLine(label: String, value: String) {
    Row(
        Modifier.fillMaxWidth().padding(vertical = 2.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(label, style = EsType.BodySm, color = SevaInk600)
        Text(value, style = EsType.BodySm.copy(fontWeight = FontWeight.SemiBold), color = SevaInk900)
    }
}

/**
 * LazyColumn key for a fleet-health row. Equipment identity is the
 * 4-part tuple (type, brand, model, serial) per the server's own
 * GROUP BY — no single column is guaranteed unique on its own (a
 * hospital may have many un-serialized units of the same type/brand,
 * all legitimately aggregated into one row with `equipment_serial`
 * NULL), so the key must combine all four.
 */
internal fun fleetItemKey(item: HospitalFleetHealthRepository.FleetHealthItem): String =
    listOf(item.equipmentType, item.equipmentBrand, item.equipmentModel, item.equipmentSerial)
        .joinToString("|") { it ?: "" }

internal fun fleetEquipmentSubtitle(item: HospitalFleetHealthRepository.FleetHealthItem): String {
    val parts = listOfNotNull(
        item.equipmentBrand?.takeIf { it.isNotBlank() },
        item.equipmentModel?.takeIf { it.isNotBlank() },
    )
    val base = parts.joinToString(" · ")
    val serial = item.equipmentSerial?.takeIf { it.isNotBlank() }
    return when {
        base.isBlank() && serial == null -> ""
        base.isBlank() -> "S/N $serial"
        serial == null -> base
        else -> "$base · S/N $serial"
    }
}
