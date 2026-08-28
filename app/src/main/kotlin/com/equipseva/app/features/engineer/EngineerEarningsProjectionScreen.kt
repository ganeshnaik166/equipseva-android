package com.equipseva.app.features.engineer

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
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
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk600
import com.equipseva.app.designsystem.theme.SevaInk900
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import java.text.NumberFormat
import java.util.Locale
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class EngineerEarningsProjectionViewModel @Inject constructor(
    private val repo: EngineerGraduationRepository,
) : ViewModel() {
    enum class Status { Loading, Loaded, Error }

    data class UiState(
        val status: Status = Status.Loading,
        val data: EngineerGraduationRepository.TierEarningsProjection? = null,
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
            repo.fetchTierEarningsProjection()
                .onSuccess { row ->
                    _state.update { UiState(status = Status.Loaded, data = row) }
                }
                .onFailure { e ->
                    _state.update {
                        UiState(
                            status = Status.Error,
                            error = e.toUserMessage("Could not load earnings projection."),
                        )
                    }
                }
        }
    }
}

@Composable
fun EngineerEarningsProjectionScreen(
    onBack: () -> Unit,
    viewModel: EngineerEarningsProjectionViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Box(Modifier.fillMaxSize().background(PaperDefault)) {
        Column(Modifier.fillMaxSize()) {
            EsTopBar(title = "Earnings projection", onBack = onBack)

            when (state.status) {
                EngineerEarningsProjectionViewModel.Status.Loading ->
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }

                EngineerEarningsProjectionViewModel.Status.Error ->
                    Column(
                        Modifier.fillMaxSize().padding(24.dp),
                        verticalArrangement = Arrangement.Center,
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        Text(stringResource(R.string.earnings_projection_load_error_title), style = EsType.H4, color = SevaInk900)
                        Spacer(Modifier.height(8.dp))
                        Text(state.error ?: "", style = EsType.Body, color = SevaInk500)
                    }

                EngineerEarningsProjectionViewModel.Status.Loaded -> {
                    val d = state.data
                    if (d == null) {
                        Box(
                            Modifier.fillMaxSize().padding(24.dp),
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(
                                stringResource(R.string.earnings_projection_no_data),
                                style = EsType.Body,
                                color = SevaInk500,
                            )
                        }
                    } else {
                        ProjectionContent(d)
                    }
                }
            }
        }
    }
}

@Composable
private fun ProjectionContent(d: EngineerGraduationRepository.TierEarningsProjection) {
    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        // Hero card — projected uplift (or top-of-ladder message)
        Box(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(SevaGreen50)
                .border(1.dp, SevaGreen700, RoundedCornerShape(12.dp))
                .padding(16.dp),
        ) {
            Column {
                when {
                    d.nextTier == null -> {
                        Text(
                            stringResource(R.string.earnings_projection_top_tier_title),
                            style = EsType.H4.copy(fontWeight = FontWeight.SemiBold),
                            color = SevaInk900,
                        )
                        Spacer(Modifier.height(4.dp))
                        Text(
                            stringResource(R.string.earnings_projection_top_tier_sub),
                            style = EsType.BodySm,
                            color = SevaGreen700,
                        )
                    }
                    d.currentPlatformFeePct == (d.nextPlatformFeePct ?: 0.0) -> {
                        // none → bronze quirk (both 7.00 fee in r550 seed)
                        Text(
                            stringResource(
                                R.string.earnings_projection_reach_tier_title,
                                d.nextTier.replaceFirstChar { it.uppercase() },
                            ),
                            style = EsType.H4.copy(fontWeight = FontWeight.SemiBold),
                            color = SevaInk900,
                        )
                        Spacer(Modifier.height(4.dp))
                        Text(
                            stringResource(R.string.earnings_projection_reach_tier_sub),
                            style = EsType.BodySm,
                            color = SevaGreen700,
                        )
                    }
                    else -> {
                        Text(
                            stringResource(
                                R.string.earnings_projection_reach_uplift_title,
                                d.nextTier.replaceFirstChar { it.uppercase() },
                                formatRupees(d.projectedMonthlyUpliftRupees),
                            ),
                            style = EsType.H4.copy(fontWeight = FontWeight.SemiBold),
                            color = SevaInk900,
                        )
                        Spacer(Modifier.height(4.dp))
                        Text(
                            stringResource(
                                R.string.earnings_projection_current_pace_sub,
                                formatRupees(d.avgMonthlyGrossRupees),
                            ),
                            style = EsType.BodySm,
                            color = SevaGreen700,
                        )
                    }
                }
            }
        }

        // Tier comparison rows
        StatCard(
            label = "Current tier",
            value = d.currentTier.replaceFirstChar { it.uppercase() },
            sub = "${"%.2f".format(d.currentPlatformFeePct)}% platform fee",
        )

        if (d.nextTier != null) {
            StatCard(
                label = "Next tier",
                value = d.nextTier.replaceFirstChar { it.uppercase() },
                sub = "${"%.2f".format(d.nextPlatformFeePct ?: 0.0)}% platform fee",
            )
        }

        StatCard(
            label = "Completed jobs (last 90 days)",
            value = "${d.completedJobs90d}",
            sub = "Avg ${formatRupees(d.avgMonthlyGrossRupees)} gross per month",
        )

        StatCard(
            label = "Supervised completions",
            value = "${d.supervisedCompletionsAtEval}",
            // r1457 — don't claim they count "toward your next tier" when
            // there is no next tier (top-tier engineer) — that contradicts
            // the hero's "You're at the top tier." message.
            sub = if (d.nextTier != null) "Counted toward your next tier (r578 gate)" else "Verified supervised completions to date",
        )

        Spacer(Modifier.height(8.dp))
        Text(
            stringResource(R.string.earnings_projection_footer_note),
            style = EsType.BodySm,
            color = SevaInk500,
        )
    }
}

@Composable
private fun StatCard(label: String, value: String, sub: String) {
    Box(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(10.dp))
            .padding(14.dp),
    ) {
        Column {
            Text(label, style = EsType.BodySm, color = SevaInk600)
            Spacer(Modifier.height(4.dp))
            Text(
                value,
                style = EsType.H4.copy(fontWeight = FontWeight.SemiBold),
                color = SevaInk900,
            )
            Spacer(Modifier.height(2.dp))
            Text(sub, style = EsType.BodySm, color = SevaInk500)
        }
    }
}

private val rupeeFmt: NumberFormat =
    NumberFormat.getCurrencyInstance(Locale("en", "IN")).apply {
        maximumFractionDigits = 0
    }

private fun formatRupees(amount: Double): String = rupeeFmt.format(amount)
