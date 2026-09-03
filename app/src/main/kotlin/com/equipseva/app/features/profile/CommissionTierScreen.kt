package com.equipseva.app.features.profile

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
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.R
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen700
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
class CommissionTierViewModel @Inject constructor(
    private val repo: CommissionTierRepository,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val tier: CommissionTierRepository.CommissionTier? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init {
        refresh()
    }

    fun refresh() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            repo.fetchMyCommissionTier()
                .onSuccess { tier -> _state.update { UiState(loading = false, tier = tier) } }
                .onFailure { e ->
                    _state.update {
                        UiState(loading = false, error = e.toUserMessage("Could not load commission tier."))
                    }
                }
        }
    }
}

@Composable
fun CommissionTierScreen(
    onBack: () -> Unit,
    viewModel: CommissionTierViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Box(Modifier.fillMaxSize().background(PaperDefault)) {
        Column(Modifier.fillMaxSize()) {
            EsTopBar(title = stringResource(R.string.commission_tier_title), onBack = onBack)

            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }

                state.error != null || state.tier == null -> EmptyStateView(
                    icon = Icons.Outlined.TrendingUp,
                    title = stringResource(R.string.commission_tier_couldnt_load),
                    subtitle = state.error,
                    ctaLabel = stringResource(R.string.commission_tier_try_again),
                    onCta = { viewModel.refresh() },
                )

                else -> Column(
                    Modifier.fillMaxSize().padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    CommissionTierCard(state.tier!!)
                    Text(
                        stringResource(R.string.commission_tier_explainer),
                        style = EsType.BodySm,
                        color = SevaInk500,
                    )
                }
            }
        }
    }
}

@Composable
private fun CommissionTierCard(tier: CommissionTierRepository.CommissionTier) {
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
                commissionRatePercentLabel(tier.currentRate),
                style = EsType.H2.copy(fontWeight = FontWeight.Bold),
                color = SevaGreen700,
            )
            Text(
                stringResource(R.string.commission_tier_current_rate_label),
                style = EsType.BodySm,
                color = SevaInk500,
            )
            Spacer(Modifier.height(14.dp))
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text(
                    stringResource(R.string.commission_tier_completed_12m),
                    style = EsType.BodySm,
                    color = SevaInk600,
                )
                Text(
                    tier.completed12m.toString(),
                    style = EsType.BodySm.copy(fontWeight = FontWeight.SemiBold),
                    color = SevaInk900,
                )
            }
            Spacer(Modifier.height(10.dp))
            Text(
                commissionTierProgressText(tier),
                style = EsType.BodySm.copy(fontWeight = FontWeight.SemiBold),
                color = SevaInk900,
            )
        }
    }
}

/** "7%" from a 0.07 fraction. Pin the rounding: 0.07 -> 7, not 7.000000004. */
internal fun commissionRatePercentLabel(rate: Double): String =
    "${Math.round(rate * 100)}%"

/**
 * "3 more completed jobs unlocks 5% commission" / "You're at the best
 * tier (3%)" — the jobs_to_next_tier + next_tier_rate pairing the
 * server always returns together (both null only at the top tier).
 */
internal fun commissionTierProgressText(tier: CommissionTierRepository.CommissionTier): String {
    val next = tier.nextTierRate
    return if (next == null) {
        "You're at the best tier (${commissionRatePercentLabel(tier.currentRate)})"
    } else {
        val n = tier.jobsToNextTier
        val jobsWord = if (n == 1) "job" else "jobs"
        "$n more completed $jobsWord unlocks ${commissionRatePercentLabel(next)} commission"
    }
}
