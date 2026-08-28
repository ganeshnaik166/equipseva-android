package com.equipseva.app.features.amc

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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
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
import com.equipseva.app.core.network.toUserMessage
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

@HiltViewModel
class HospitalAmcTierPerksViewModel @Inject constructor(
    private val repo: HospitalAmcTierPerksRepository,
) : ViewModel() {
    enum class Status { Loading, Loaded, Error }

    data class UiState(
        val status: Status = Status.Loading,
        val rows: List<HospitalAmcTierPerksRepository.TierPerks> = emptyList(),
        val error: String? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init {
        reload()
    }

    fun reload() {
        _state.update { it.copy(status = Status.Loading, error = null) }
        viewModelScope.launch {
            repo.fetchActiveTierPerks()
                .onSuccess { list ->
                    _state.update { UiState(status = Status.Loaded, rows = list) }
                }
                .onFailure { e ->
                    _state.update {
                        UiState(
                            status = Status.Error,
                            error = e.toUserMessage("Could not load tier perks."),
                        )
                    }
                }
        }
    }
}

@Composable
fun HospitalAmcTierPerksScreen(
    onBack: () -> Unit,
    viewModel: HospitalAmcTierPerksViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Box(Modifier.fillMaxSize().background(PaperDefault)) {
        Column(Modifier.fillMaxSize()) {
            EsTopBar(title = "AMC tier perks", onBack = onBack)

            when (state.status) {
                HospitalAmcTierPerksViewModel.Status.Loading ->
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }

                HospitalAmcTierPerksViewModel.Status.Error ->
                    Column(
                        Modifier.fillMaxSize().padding(24.dp),
                        verticalArrangement = Arrangement.Center,
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        Text(stringResource(R.string.hospital_amc_tier_perks_couldnt_load), style = EsType.H4, color = SevaInk900)
                        Spacer(Modifier.height(8.dp))
                        Text(state.error ?: "", style = EsType.Body, color = SevaInk500)
                    }

                HospitalAmcTierPerksViewModel.Status.Loaded -> {
                    if (state.rows.isEmpty()) {
                        EmptyState()
                    } else {
                        Column(
                            Modifier
                                .fillMaxSize()
                                .verticalScroll(rememberScrollState())
                                .padding(16.dp),
                            verticalArrangement = Arrangement.spacedBy(10.dp),
                        ) {
                            Text(
                                stringResource(R.string.hospital_amc_tier_perks_active_count, state.rows.size),
                                style = EsType.H5,
                                color = SevaInk900,
                            )
                            state.rows.forEach { row -> PerksCard(row) }
                            Spacer(Modifier.height(8.dp))
                            Text(
                                stringResource(R.string.hospital_amc_tier_perks_sorted_note),
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

@Composable
private fun PerksCard(row: HospitalAmcTierPerksRepository.TierPerks) {
    val tierTone = when (row.amcTier) {
        "gold" -> PillKind.Lime
        "silver" -> PillKind.Neutral
        "bronze" -> PillKind.Warn
        else -> PillKind.Default
    }
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
                    row.displayLabel,
                    style = EsType.H5.copy(fontWeight = FontWeight.SemiBold),
                    color = SevaInk900,
                )
                Pill(text = row.amcTier.uppercase(), kind = tierTone)
            }
            Spacer(Modifier.height(2.dp))
            Text(
                stringResource(R.string.hospital_amc_tier_perks_active_until, row.endDate),
                style = EsType.BodySm,
                color = SevaInk500,
            )
            Spacer(Modifier.height(10.dp))

            if (row.visitsPerYearCeiling != null) {
                PerkLine(
                    label = "Preventive visits",
                    value = "${row.visitsPerYearCeiling}/year",
                )
            }
            if (row.codeRedSlaMinutes != null) {
                PerkLine(
                    label = "Code Red response",
                    value = "≤ ${row.codeRedSlaMinutes} min",
                )
            }
            if (row.partsDiscountPct != null && row.partsDiscountPct > 0.0) {
                PerkLine(
                    label = "Parts discount",
                    value = "${String.format(java.util.Locale.US, "%.1f", row.partsDiscountPct)}%",
                )
            }
            if (row.trustedPartnerBadge) {
                PerkLine(
                    label = "Trusted partner badge",
                    value = "Yes",
                )
            }
        }
    }
}

@Composable
private fun PerkLine(label: String, value: String) {
    Row(
        Modifier
            .fillMaxWidth()
            .padding(vertical = 2.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(label, style = EsType.BodySm, color = SevaInk600)
        Text(value, style = EsType.BodySm.copy(fontWeight = FontWeight.SemiBold), color = SevaInk900)
    }
}

@Composable
private fun EmptyState() {
    Column(
        Modifier.fillMaxSize().padding(24.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(stringResource(R.string.hospital_amc_tier_perks_empty_title), style = EsType.H4, color = SevaInk900)
        Spacer(Modifier.height(8.dp))
        Text(
            stringResource(R.string.hospital_amc_tier_perks_empty_body),
            style = EsType.BodySm,
            color = SevaInk500,
        )
    }
}
