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
import androidx.compose.material.icons.outlined.TrendingUp
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
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
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
class HospitalTierPreviewViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val repo: HospitalTierPreviewRepository,
) : ViewModel() {

    private val repairJobId: String? = savedStateHandle[Routes.HOSPITAL_TIER_PREVIEW_ARG_JOB_ID]

    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val preview: HospitalTierPreviewRepository.TierPreview? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init {
        refresh()
    }

    fun refresh() {
        val id = repairJobId
        if (id.isNullOrBlank()) {
            _state.update { UiState(loading = false, error = "No job selected.") }
            return
        }
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            repo.fetchTierPreview(id)
                .onSuccess { preview -> _state.update { UiState(loading = false, preview = preview) } }
                .onFailure { e ->
                    _state.update {
                        UiState(loading = false, error = e.toUserMessage("Could not load payout preview."))
                    }
                }
        }
    }
}

@Composable
fun HospitalTierPreviewScreen(
    onBack: () -> Unit,
    viewModel: HospitalTierPreviewViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Box(Modifier.fillMaxSize().background(PaperDefault)) {
        Column(Modifier.fillMaxSize()) {
            EsTopBar(title = stringResource(R.string.hospital_tier_preview_title), onBack = onBack)

            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }

                state.error != null || state.preview == null -> EmptyStateView(
                    icon = Icons.Outlined.TrendingUp,
                    title = stringResource(R.string.hospital_tier_preview_couldnt_load),
                    subtitle = state.error,
                    ctaLabel = stringResource(R.string.hospital_tier_preview_try_again),
                    onCta = { viewModel.refresh() },
                )

                else -> Column(
                    Modifier.fillMaxSize().padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(14.dp),
                ) {
                    TierPreviewCard(state.preview!!)
                    Text(
                        stringResource(R.string.hospital_tier_preview_explainer),
                        style = EsType.BodySm,
                        color = SevaInk500,
                    )
                }
            }
        }
    }
}

@Composable
private fun TierPreviewCard(p: HospitalTierPreviewRepository.TierPreview) {
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
                    formatRupees(p.effectivePayoutRupees),
                    style = EsType.H2.copy(fontWeight = FontWeight.Bold),
                    color = SevaGreen700,
                )
                if (p.isWarrantyCovered) {
                    Pill(text = stringResource(R.string.hospital_tier_preview_warranty), kind = PillKind.Info)
                }
            }
            Text(
                stringResource(R.string.hospital_tier_preview_effective_payout_label),
                style = EsType.BodySm,
                color = SevaInk500,
            )
            Spacer(Modifier.height(12.dp))
            TierLine(
                stringResource(R.string.hospital_tier_preview_contracted_amount),
                formatRupees(p.contractedAmountRupees),
            )
            TierLine(
                stringResource(R.string.hospital_tier_preview_commission_rate),
                "${Math.round(p.commissionRate * 100)}%",
            )
        }
    }
}

@Composable
private fun TierLine(label: String, value: String) {
    Row(
        Modifier.fillMaxWidth().padding(vertical = 3.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(label, style = EsType.BodySm, color = SevaInk600)
        Text(value, style = EsType.BodySm.copy(fontWeight = FontWeight.SemiBold), color = SevaInk900)
    }
}
