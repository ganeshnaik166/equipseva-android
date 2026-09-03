package com.equipseva.app.features.mybids

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CurrencyRupee
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
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
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsField
import com.equipseva.app.designsystem.components.EsFieldType
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk600
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
class JobProfitabilityViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val repo: JobProfitabilityRepository,
) : ViewModel() {

    private val bidId: String? = savedStateHandle[Routes.JOB_PROFITABILITY_ARG_BID_ID]

    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val data: JobProfitabilityRepository.Profitability? = null,
        val savingFloor: Boolean = false,
        val floorSaved: Boolean = false,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init {
        refresh()
    }

    fun refresh() {
        val id = bidId
        if (id.isNullOrBlank()) {
            _state.update { UiState(loading = false, error = "No bid selected.") }
            return
        }
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            repo.fetchProfitability(id)
                .onSuccess { data -> _state.update { UiState(loading = false, data = data) } }
                .onFailure { e ->
                    _state.update {
                        UiState(loading = false, error = e.toUserMessage("Could not load profitability."))
                    }
                }
        }
    }

    fun saveFloor(floorRupees: Double) {
        _state.update { it.copy(savingFloor = true, floorSaved = false) }
        viewModelScope.launch {
            repo.updateFloor(floorRupees)
                .onSuccess {
                    _state.update { it.copy(savingFloor = false, floorSaved = true) }
                    refresh()
                }
                .onFailure { e ->
                    _state.update {
                        it.copy(savingFloor = false, error = e.toUserMessage("Could not update your floor."))
                    }
                }
        }
    }
}

@Composable
fun JobProfitabilityScreen(
    onBack: () -> Unit,
    viewModel: JobProfitabilityViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Box(Modifier.fillMaxSize().background(PaperDefault)) {
        Column(Modifier.fillMaxSize()) {
            EsTopBar(title = stringResource(R.string.job_profitability_title), onBack = onBack)

            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }

                state.error != null && state.data == null -> EmptyStateView(
                    icon = Icons.Outlined.CurrencyRupee,
                    title = stringResource(R.string.job_profitability_couldnt_load),
                    subtitle = state.error,
                    ctaLabel = stringResource(R.string.job_profitability_try_again),
                    onCta = { viewModel.refresh() },
                )

                state.data != null -> Column(
                    Modifier.fillMaxSize().padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(14.dp),
                ) {
                    ProfitabilityCard(state.data!!)
                    FloorEditor(
                        currentFloor = state.data!!.profitabilityFloorRupees,
                        saving = state.savingFloor,
                        saved = state.floorSaved,
                        onSave = viewModel::saveFloor,
                    )
                    Text(
                        stringResource(R.string.job_profitability_explainer),
                        style = EsType.BodySm,
                        color = SevaInk500,
                    )
                }
            }
        }
    }
}

@Composable
private fun ProfitabilityCard(p: JobProfitabilityRepository.Profitability) {
    Box(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(16.dp),
    ) {
        Column {
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    formatRupees(p.estimatedNetRupees),
                    style = EsType.H2.copy(fontWeight = FontWeight.Bold),
                    color = if (p.belowFloor) SevaDanger500 else SevaGreen700,
                )
                if (p.belowFloor) {
                    Pill(text = stringResource(R.string.job_profitability_below_floor), kind = PillKind.Danger)
                }
            }
            Text(
                stringResource(R.string.job_profitability_estimated_net_label),
                style = EsType.BodySm,
                color = SevaInk500,
            )
            Spacer(Modifier.height(12.dp))
            ProfitLine(stringResource(R.string.job_profitability_gross_bid), formatRupees(p.grossBidRupees))
            ProfitLine(
                stringResource(R.string.job_profitability_platform_fee),
                "− ${formatRupees(p.platformFeeRupees)}",
            )
            ProfitLine(
                stringResource(R.string.job_profitability_tds_estimate),
                "− ${formatRupees(p.tdsEstimateRupees)}",
            )
            ProfitLine(
                stringResource(R.string.job_profitability_travel_cost),
                "− ${formatRupees(p.estimatedTravelCostRupees)}" +
                    (p.distanceKm?.let { " ($it km round trip)" } ?: ""),
            )
            Box(Modifier.fillMaxWidth().height(1.dp).background(BorderDefault).padding(vertical = 4.dp))
            ProfitLine(
                stringResource(R.string.job_profitability_your_floor),
                formatRupees(p.profitabilityFloorRupees),
            )
        }
    }
}

@Composable
private fun ProfitLine(label: String, value: String) {
    Row(
        Modifier.fillMaxWidth().padding(vertical = 3.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(label, style = EsType.BodySm, color = SevaInk600)
        Text(value, style = EsType.BodySm.copy(fontWeight = FontWeight.SemiBold), color = SevaInk900)
    }
}

@Composable
private fun FloorEditor(
    currentFloor: Double,
    saving: Boolean,
    saved: Boolean,
    onSave: (Double) -> Unit,
) {
    var text by rememberSaveable(currentFloor) { mutableStateOf(currentFloor.toInt().toString()) }
    Box(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(16.dp),
    ) {
        Column {
            Text(
                stringResource(R.string.job_profitability_floor_editor_title),
                style = EsType.Body.copy(fontWeight = FontWeight.SemiBold),
                color = SevaInk900,
            )
            Spacer(Modifier.height(8.dp))
            Row(
                Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.Bottom,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                EsField(
                    value = text,
                    onChange = { text = it.filter(Char::isDigit) },
                    type = EsFieldType.Number,
                    modifier = Modifier.weight(1f),
                )
                EsBtn(
                    text = if (saving) {
                        stringResource(R.string.job_profitability_floor_saving)
                    } else {
                        stringResource(R.string.job_profitability_floor_save)
                    },
                    onClick = { text.toDoubleOrNull()?.let(onSave) },
                    kind = EsBtnKind.Secondary,
                    disabled = saving || text.toDoubleOrNull() == null,
                )
            }
            if (saved) {
                Spacer(Modifier.height(4.dp))
                Text(
                    stringResource(R.string.job_profitability_floor_saved),
                    style = EsType.Caption,
                    color = SevaGreen700,
                )
            }
        }
    }
}
