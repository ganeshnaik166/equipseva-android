package com.equipseva.app.features.amc

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.History
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
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.R
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.navigation.Routes
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
 * Round 3771 — "tap into an asset" drill-down for [HospitalFleetHealthScreen],
 * backed by the round508 `asset_history` RPC (chronological union of
 * repair_jobs + dsr_reports + equipment_pm_schedule for one serial).
 */
@HiltViewModel
class HospitalAssetHistoryViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val repo: HospitalFleetHealthRepository,
    private val auth: AuthRepository,
) : ViewModel() {

    private val equipmentSerial: String? =
        savedStateHandle[Routes.HOSPITAL_ASSET_HISTORY_ARG_SERIAL]

    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val error: String? = null,
        val events: List<HospitalFleetHealthRepository.AssetHistoryEvent> = emptyList(),
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
                loading = initial || it.events.isEmpty(),
                refreshing = !initial && it.events.isNotEmpty(),
                error = null,
            )
        }
        viewModelScope.launch {
            val serial = equipmentSerial
            val userId = auth.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .firstOrNull()
                ?.userId
            if (serial.isNullOrBlank() || userId == null) {
                _state.update { UiState(loading = false, refreshing = false, events = emptyList()) }
                return@launch
            }
            repo.fetchAssetHistory(userId, serial)
                .onSuccess { list ->
                    _state.update { UiState(loading = false, refreshing = false, events = list) }
                }
                .onFailure { e ->
                    _state.update {
                        UiState(
                            loading = false,
                            refreshing = false,
                            error = e.toUserMessage("Could not load asset history."),
                        )
                    }
                }
        }
    }
}

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun HospitalAssetHistoryScreen(
    onBack: () -> Unit,
    viewModel: HospitalAssetHistoryViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Box(Modifier.fillMaxSize().background(PaperDefault)) {
        Column(Modifier.fillMaxSize()) {
            EsTopBar(title = stringResource(R.string.hospital_asset_history_title), onBack = onBack)

            androidx.compose.material3.pulltorefresh.PullToRefreshBox(
                isRefreshing = state.refreshing,
                onRefresh = viewModel::onPullToRefresh,
                modifier = Modifier.fillMaxSize(),
            ) {
                when {
                    state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }

                    state.error != null && state.events.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.History,
                        title = stringResource(R.string.hospital_asset_history_couldnt_load),
                        subtitle = state.error,
                        ctaLabel = stringResource(R.string.hospital_asset_history_try_again),
                        onCta = { viewModel.refresh() },
                    )

                    state.events.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.History,
                        title = stringResource(R.string.hospital_asset_history_empty_title),
                        subtitle = stringResource(R.string.hospital_asset_history_empty_body),
                    )

                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        items(state.events, key = { "${it.eventKind}_${it.referenceId}" }) { event ->
                            AssetHistoryCard(event)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun AssetHistoryCard(event: HospitalFleetHealthRepository.AssetHistoryEvent) {
    Box(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(14.dp),
    ) {
        Column {
            Text(
                assetHistoryEventKindLabel(event.eventKind),
                style = EsType.Label,
                color = SevaInk500,
            )
            Spacer(Modifier.height(2.dp))
            Text(
                event.summary,
                style = EsType.Body.copy(fontWeight = FontWeight.SemiBold),
                color = SevaInk900,
            )
            if (event.eventAt != null) {
                Spacer(Modifier.height(4.dp))
                Text(prettyDate(event.eventAt), style = EsType.BodySm, color = SevaInk500)
            }
        }
    }
}

internal fun assetHistoryEventKindLabel(eventKind: String): String = when (eventKind) {
    "repair_job" -> "Repair job"
    "dsr_report" -> "Service report"
    "pm_scheduled" -> "Preventive maintenance"
    else -> eventKind.replaceFirstChar { it.uppercase() }
}
