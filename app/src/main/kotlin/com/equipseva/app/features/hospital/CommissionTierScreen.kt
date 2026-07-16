package com.equipseva.app.features.hospital

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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Loyalty
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.hospital.CommissionTierRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
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
class CommissionTierViewModel @Inject constructor(
    private val repo: CommissionTierRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val data: CommissionTierRepository.CommissionTier? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload() }

    fun reload() {
        _state.update { it.copy(loading = it.data == null, error = null) }
        viewModelScope.launch {
            repo.fetch()
                .onSuccess { d -> _state.update { it.copy(loading = false, data = d) } }
                .onFailure { e ->
                    _state.update { if (it.data == null) it.copy(loading = false, error = e.toUserMessage()) else it.copy(loading = false) }
                }
        }
    }
}

/**
 * Hospital loyalty / commission-transparency self-view (r1405): completed jobs
 * in the trailing 12 months, the current platform commission rate, and how
 * many more jobs unlock the next (cheaper) tier. Surfaces
 * get_my_commission_tier() (v2.1 PR-D2), which had no Android screen before.
 */
@Composable
fun CommissionTierScreen(
    onBack: () -> Unit,
    viewModel: CommissionTierViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "Commission tier", onBack = onBack)
            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                state.error != null || state.data == null -> EmptyStateView(
                    icon = Icons.Outlined.Loyalty,
                    title = "Couldn't load commission tier",
                    subtitle = state.error ?: "No data available.",
                    ctaLabel = "Try again",
                    onCta = { viewModel.reload() },
                )
                else -> {
                    val d = state.data!!
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .verticalScroll(rememberScrollState())
                            .padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        RateHeroCard(d)
                        Text(
                            commissionNextTierMessage(d.nextTierRate, d.jobsToNextTier),
                            style = EsType.Body,
                            color = SevaInk700,
                        )
                        Text(
                            "Platform commission is charged on each completed job. Doing more jobs on EquipSeva lowers your rate: 10 jobs a year unlocks a better tier, 50 the best.",
                            style = EsType.Caption,
                            color = SevaInk500,
                        )
                        Spacer(Modifier.height(8.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun RateHeroCard(d: CommissionTierRepository.CommissionTier) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(SevaGreen50)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("Your commission rate", style = EsType.BodySm, color = SevaInk700)
            Pill(text = commissionTierName(d.currentRate), kind = commissionTierPillKind(d.currentRate))
        }
        Text(
            formatRatePct(d.currentRate),
            style = EsType.H3.copy(fontWeight = FontWeight.Bold),
            color = SevaGreen700,
        )
        Text(
            "${d.completed12m} jobs completed in the last 12 months",
            style = EsType.Caption,
            color = SevaInk500,
        )
    }
}

// ---------------------------------------------------------------------
//  Pinned helpers
// ---------------------------------------------------------------------

/**
 * Formats a commission fraction (0.07) as a whole-ish percentage ("7%").
 * Rounds to one decimal so a stray numeric never spills; drops a redundant
 * decimal. Guards against the double-format ₹/% bugs seen in earlier audits.
 */
internal fun formatRatePct(fraction: Double): String {
    val pct = fraction * 100.0
    val rounded = kotlin.math.round(pct * 10.0) / 10.0
    val s = if (rounded % 1.0 == 0.0) rounded.toLong().toString() else rounded.toString()
    return "$s%"
}

/** Descriptive tier name by rate (3% best → "Top tier", 5% → "Preferred", else "Standard"). */
internal fun commissionTierName(fraction: Double): String = when {
    fraction <= 0.03 -> "Top tier"
    fraction <= 0.05 -> "Preferred"
    else -> "Standard"
}

/** Pill tone matching the tier name. */
internal fun commissionTierPillKind(fraction: Double): PillKind = when {
    fraction <= 0.03 -> PillKind.Success
    fraction <= 0.05 -> PillKind.Info
    else -> PillKind.Neutral
}

/**
 * Next-tier coaching line. null next-rate → already on the best rate;
 * otherwise "Complete N more job(s)… to unlock X% commission."
 */
internal fun commissionNextTierMessage(nextTierRate: Double?, jobsToNext: Int): String {
    if (nextTierRate == null) return "You're on our best commission rate."
    val jobs = if (jobsToNext < 0) 0 else jobsToNext
    val jobWord = if (jobs == 1) "job" else "jobs"
    return "Complete $jobs more $jobWord in the next 12 months to unlock ${formatRatePct(nextTierRate)} commission."
}
