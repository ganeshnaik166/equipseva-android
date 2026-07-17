package com.equipseva.app.features.engineer

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
import androidx.compose.material.icons.outlined.Speed
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
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.engineers.SlaCardRepository
import com.equipseva.app.core.data.engineers.disputeRateBand
import com.equipseva.app.core.data.engineers.formatSlaHours
import com.equipseva.app.core.data.engineers.onTimeBand
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
import java.util.Locale
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class EngineerSlaViewModel @Inject constructor(
    private val repo: SlaCardRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val data: SlaCardRepository.SlaCard? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload() }

    fun reload() {
        _state.update { it.copy(loading = it.data == null, error = null) }
        viewModelScope.launch {
            repo.fetch()
                .onSuccess { d -> _state.update { it.copy(loading = false, data = d) } }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.toUserMessage()) } }
        }
    }
}

/**
 * "My SLA" — the engineer's own 30-day service-level scorecard: on-time %,
 * dispute rate, average accept→arrival and arrival→complete times, and SLA
 * breach count. Read-only; a self-coaching lens that surfaces
 * my_sla_card() (round 506), which had no Android screen before r1397.
 */
@Composable
fun EngineerSlaScreen(
    onBack: () -> Unit,
    viewModel: EngineerSlaViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "My SLA", onBack = onBack)
            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                state.error != null || state.data == null -> EmptyStateView(
                    icon = Icons.Outlined.Speed,
                    title = "Couldn't load your SLA",
                    subtitle = state.error ?: "Complete a few repair jobs and your 30-day scorecard shows up here.",
                    ctaLabel = state.error?.let { "Try again" },
                    onCta = { viewModel.reload() },
                )
                else -> {
                    val d = state.data!!
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .verticalScroll(rememberScrollState())
                            .padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        OnTimeCard(onTimePct = d.onTimePct)
                        StatRow("Jobs completed", "${d.jobsCompletedWindow}")
                        DisputeRow(disputeRatePct = d.disputeRatePct, disputed = d.jobsDisputedWindow)
                        StatRow("SLA breaches", "${d.slaBreaches}")
                        StatRow("Avg accept → arrival", formatSlaHours(d.avgAcceptToArrivalHrs))
                        StatRow("Avg arrival → complete", formatSlaHours(d.avgArrivalToCompleteHrs))
                        Spacer(Modifier.height(4.dp))
                        Text(
                            "Based on your accepted jobs over the last 30 days.",
                            style = EsType.Caption,
                            color = SevaInk500,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun OnTimeCard(onTimePct: Double) {
    // Round once and band on the rounded value so the big number and the pill
    // can't disagree (94.6 shows "95%" — must not pill "Good" when 95% is the
    // "Excellent" cutpoint).
    val shownPct = Math.round(onTimePct).toInt()
    val (bandText, bandKind) = onTimePillTextAndKind(shownPct.toDouble())
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
            Text("On-time delivery", style = EsType.BodySm, color = SevaInk700)
            Pill(text = bandText, kind = bandKind)
        }
        Text(
            "$shownPct%",
            style = EsType.H3.copy(fontWeight = FontWeight.Bold),
            color = SevaGreen700,
        )
        Text("of jobs delivered on time (last 30 days)", style = EsType.Caption, color = SevaInk500)
    }
}

@Composable
private fun StatRow(label: String, value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(10.dp))
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(label, style = EsType.Body, color = SevaInk900)
        Text(value, style = EsType.Body.copy(fontWeight = FontWeight.SemiBold), color = SevaInk900)
    }
}

@Composable
private fun DisputeRow(disputeRatePct: Double, disputed: Int) {
    // Round to the 1 decimal the caption shows, then band on it, so the number
    // and the pill agree at the cutpoints (4.97 shows "5.0%" → band Elevated,
    // not "Low"; 0.04 shows "0.0%" → Clean, not Low).
    val shownRate = Math.round(disputeRatePct * 10.0) / 10.0
    val (pillText, pillKind) = disputeRatePillTextAndKind(shownRate)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(10.dp))
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text("Dispute rate", style = EsType.Body, color = SevaInk900)
            Text(
                "%.1f%% · %d disputed".format(Locale.ROOT, shownRate, disputed),
                style = EsType.Caption,
                color = SevaInk500,
            )
        }
        Pill(text = pillText, kind = pillKind)
    }
}

// ---------------------------------------------------------------------
//  Pinned helpers
// ---------------------------------------------------------------------

/**
 * On-time % → hero pill. Reuses [onTimeBand] so the pill label and any
 * downstream banding share one definition:
 *   * excellent → "Excellent" (Success)
 *   * good      → "Good"       (Warn)
 *   * attention → "Needs work" (Danger)
 */
internal fun onTimePillTextAndKind(onTimePct: Double): Pair<String, PillKind> =
    when (onTimeBand(onTimePct)) {
        "excellent" -> "Excellent" to PillKind.Success
        "good" -> "Good" to PillKind.Warn
        else -> "Needs work" to PillKind.Danger
    }

/**
 * Dispute-rate % → pill. Reuses [disputeRateBand]:
 *   * clean    → "Clean record" (Success)
 *   * low      → "Low"          (Warn)
 *   * elevated → "Elevated"     (Danger)
 */
internal fun disputeRatePillTextAndKind(disputeRatePct: Double): Pair<String, PillKind> =
    when (disputeRateBand(disputeRatePct)) {
        "clean" -> "Clean record" to PillKind.Success
        "low" -> "Low" to PillKind.Warn
        else -> "Elevated" to PillKind.Danger
    }
