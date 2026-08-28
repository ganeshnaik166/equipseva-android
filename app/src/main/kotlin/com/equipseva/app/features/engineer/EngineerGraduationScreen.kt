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
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk400
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
 * Engineer tier-graduation cockpit. Calls r578 my_supervision_graduation_status()
 * to show the engineer their current tier and what's needed to reach the next.
 * 4 gates: jobs completed, dispute rate, KYC verified tier, supervised completions.
 */
@HiltViewModel
class EngineerGraduationViewModel @Inject constructor(
    private val repo: EngineerGraduationRepository,
) : ViewModel() {

    enum class Status { Loading, Loaded, Error }

    data class UiState(
        val status: Status = Status.Loading,
        val data: EngineerGraduationRepository.GraduationStatus? = null,
        val history: List<EngineerGraduationRepository.TierHistoryEntry> = emptyList(),
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
            val statusResult = repo.fetchGraduationStatus()
            val historyResult = repo.fetchTierHistory()
            statusResult
                .onSuccess { row ->
                    _state.update {
                        UiState(
                            status = Status.Loaded,
                            data = row,
                            history = historyResult.getOrNull().orEmpty(),
                        )
                    }
                }
                .onFailure { e ->
                    _state.update {
                        UiState(
                            status = Status.Error,
                            error = e.toUserMessage("Could not load graduation status."),
                        )
                    }
                }
        }
    }
}

@Composable
fun EngineerGraduationScreen(
    onBack: () -> Unit,
    viewModel: EngineerGraduationViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Box(Modifier.fillMaxSize().background(PaperDefault)) {
        Column(Modifier.fillMaxSize()) {
            EsTopBar(title = "Tier progress", onBack = onBack)

            when (state.status) {
                EngineerGraduationViewModel.Status.Loading ->
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }

                EngineerGraduationViewModel.Status.Error ->
                    Column(
                        Modifier
                            .fillMaxSize()
                            .padding(24.dp),
                        verticalArrangement = Arrangement.Center,
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        Text(
                            stringResource(R.string.engineer_graduation_error_title),
                            style = EsType.H4,
                            color = SevaInk900,
                        )
                        Spacer(Modifier.height(8.dp))
                        Text(
                            state.error ?: "",
                            style = EsType.Body,
                            color = SevaInk500,
                        )
                    }

                EngineerGraduationViewModel.Status.Loaded -> {
                    val d = state.data
                    if (d == null) {
                        Column(
                            Modifier
                                .fillMaxSize()
                                .padding(24.dp),
                            verticalArrangement = Arrangement.Center,
                            horizontalAlignment = Alignment.CenterHorizontally,
                        ) {
                            Text(
                                stringResource(R.string.engineer_graduation_no_data_title),
                                style = EsType.H4,
                                color = SevaInk900,
                            )
                            Spacer(Modifier.height(8.dp))
                            Text(
                                stringResource(R.string.engineer_graduation_no_data_body),
                                style = EsType.Body,
                                color = SevaInk500,
                            )
                        }
                    } else {
                        GraduationContent(d, state.history)
                    }
                }
            }
        }
    }
}

@Composable
private fun GraduationContent(
    d: EngineerGraduationRepository.GraduationStatus,
    history: List<EngineerGraduationRepository.TierHistoryEntry>,
) {
    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        // Current tier hero
        Box(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(SevaGreen50)
                .border(1.dp, SevaGreen700, RoundedCornerShape(12.dp))
                .padding(16.dp),
        ) {
            Column {
                Text(
                    stringResource(R.string.engineer_graduation_current_tier_label),
                    style = EsType.BodySm,
                    color = SevaInk600,
                )
                Spacer(Modifier.height(2.dp))
                Text(
                    d.currentTier.replaceFirstChar { it.uppercase() },
                    style = EsType.H4.copy(fontWeight = FontWeight.SemiBold),
                    color = SevaInk900,
                )
                if (d.nextTier != null) {
                    Spacer(Modifier.height(6.dp))
                    Text(
                        stringResource(
                            R.string.engineer_graduation_next_tier,
                            d.nextTier.replaceFirstChar { it.uppercase() },
                        ),
                        style = EsType.BodySm,
                        color = SevaGreen700,
                    )
                } else {
                    Spacer(Modifier.height(6.dp))
                    Text(
                        stringResource(R.string.engineer_graduation_top_tier),
                        style = EsType.BodySm,
                        color = SevaGreen700,
                    )
                }
            }
        }

        if (d.nextTier != null) {
            Text(
                stringResource(
                    R.string.engineer_graduation_what_you_need,
                    d.nextTier.replaceFirstChar { it.uppercase() },
                ),
                style = EsType.H5,
                color = SevaInk900,
                modifier = Modifier.padding(top = 4.dp),
            )

            GateCard(
                label = "Completed jobs",
                current = d.jobsCompleted.toString(),
                target = d.jobsRequiredForNext?.toString() ?: "—",
                met = d.jobsRequiredForNext == null ||
                    d.jobsCompleted >= d.jobsRequiredForNext,
            )

            // Dispute rate is a CEILING, not a floor — lower is better.
            val disputeMet = d.maxDisputeRateForNext == null ||
                d.disputeRatePct <= d.maxDisputeRateForNext
            GateCard(
                label = "Dispute rate (max)",
                current = String.format(java.util.Locale.ROOT, "%.1f%%", d.disputeRatePct),
                target = d.maxDisputeRateForNext?.let { String.format(java.util.Locale.ROOT, "≤ %.1f%%", it) } ?: "—",
                met = disputeMet,
            )

            GateCard(
                label = "KYC verified tier",
                current = d.verifiedTierAtEval.replaceFirstChar { it.uppercase() },
                target = d.minVerifiedTierForNext?.replaceFirstChar { it.uppercase() } ?: "—",
                met = d.minVerifiedTierForNext == null ||
                    verifiedRank(d.verifiedTierAtEval) >=
                        verifiedRank(d.minVerifiedTierForNext),
            )

            GateCard(
                label = "Supervised completions",
                current = d.supervisedCompleted.toString(),
                target = d.supervisedRequiredForNext?.toString() ?: "0",
                met = (d.supervisedRequiredForNext ?: 0) <= d.supervisedCompleted,
                note = if ((d.supervisedRequiredForNext ?: 0) == 0)
                    "No requirement at current threshold."
                else
                    "Ask a higher-tier engineer to supervise you on a job.",
            )
        }

        Spacer(Modifier.height(8.dp))
        Text(
            stringResource(R.string.engineer_graduation_refresh_note),
            style = EsType.BodySm,
            color = SevaInk400,
        )

        // r594 — Promotion history (from r593 ledger). Rendered only
        // when the engineer has at least one tier change in history.
        if (history.isNotEmpty()) {
            Spacer(Modifier.height(12.dp))
            Text(
                stringResource(R.string.engineer_graduation_promotion_history_title),
                style = EsType.H5,
                color = SevaInk900,
            )
            history.forEach { h -> TierHistoryRow(h) }
        }
    }
}

@Composable
private fun TierHistoryRow(h: EngineerGraduationRepository.TierHistoryEntry) {
    val arrow = "${h.prevTier.replaceFirstChar { it.uppercase() }} → ${h.newTier.replaceFirstChar { it.uppercase() }}"
    val kindLabel = when (h.changeKind) {
        "cron_compute" -> "auto"
        "founder_override" -> "founder override"
        "founder_promote" -> "founder promotion"
        "founder_demote" -> "founder demotion"
        else -> h.changeKind
    }
    Box(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(10.dp))
            .padding(12.dp),
    ) {
        Column {
            Text(arrow, style = EsType.Body.copy(fontWeight = FontWeight.SemiBold), color = SevaInk900)
            Spacer(Modifier.height(2.dp))
            Text(
                stringResource(R.string.engineer_graduation_history_row, kindLabel, h.changedAt.take(10)),
                style = EsType.BodySm,
                color = SevaInk500,
            )
        }
    }
}

@Composable
private fun GateCard(
    label: String,
    current: String,
    target: String,
    met: Boolean,
    note: String? = null,
) {
    Box(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(10.dp))
            .padding(14.dp),
    ) {
        Column {
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(label, style = EsType.BodySm, color = SevaInk600)
                Pill(
                    text = if (met) "Met" else "Pending",
                    kind = if (met) PillKind.Success else PillKind.Warn,
                )
            }
            Spacer(Modifier.height(6.dp))
            Row(verticalAlignment = Alignment.Bottom) {
                Text(
                    current,
                    style = EsType.H4.copy(fontWeight = FontWeight.SemiBold),
                    color = SevaInk900,
                )
                Spacer(Modifier.height(0.dp))
                Text(
                    stringResource(R.string.engineer_graduation_gate_target, target),
                    style = EsType.Body,
                    color = SevaInk500,
                )
            }
            if (note != null) {
                Spacer(Modifier.height(6.dp))
                Text(note, style = EsType.BodySm, color = SevaInk500)
            }
        }
    }
}

// Mirrors the r550 _verified_tier_at_or_above private helper.
private fun verifiedRank(tier: String): Int = when (tier) {
    "none" -> 0
    "aadhaar" -> 1
    "pan" -> 2
    "gst" -> 3
    "bgc" -> 4
    "pro" -> 5
    else -> 0
}
