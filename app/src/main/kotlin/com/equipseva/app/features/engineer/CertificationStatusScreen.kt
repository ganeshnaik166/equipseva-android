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
import androidx.compose.material.icons.outlined.WorkspacePremium
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
import com.equipseva.app.core.data.engineers.CertificationStatusRepository
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
class CertificationStatusViewModel @Inject constructor(
    private val repo: CertificationStatusRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val data: CertificationStatusRepository.CertificationStatus? = null,
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
 * Engineer certification-ladder self-view (r1404): current tier badge + live
 * stats, the perks that tier unlocks (platform fee, code-red priority, PI
 * insurance, featured-in-search), and what the next tier requires. Surfaces
 * my_certification_status() (round 554), which had no Android screen before.
 */
@Composable
fun CertificationStatusScreen(
    onBack: () -> Unit,
    viewModel: CertificationStatusViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "Certification", onBack = onBack)
            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                state.error != null || state.data == null -> EmptyStateView(
                    icon = Icons.Outlined.WorkspacePremium,
                    title = "Couldn't load certification",
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
                        TierHeroCard(d)
                        if (d.manualOverride) {
                            Text(
                                "Your tier was set manually by the EquipSeva team.",
                                style = EsType.Caption,
                                color = SevaInk500,
                            )
                        }
                        SectionHeader("Your benefits")
                        BenefitRow("Platform fee", formatPercent(d.currentPlatformFeePct))
                        BenefitRow("Code Red priority", codeRedPriorityLabel(d.currentCodeRedPriority))
                        BenefitRow("PI insurance", if (d.currentPiInsuranceEligible) "Eligible" else "Not yet")
                        BenefitRow("Featured in search", if (d.currentFeaturedInSearch) "Yes" else "No")

                        if (d.nextTier != null) {
                            SectionHeader("Reach ${d.nextTierLabel ?: d.nextTier}")
                            NextTierCard(d)
                        } else {
                            Text(
                                "You're at the top tier — the best perks EquipSeva offers.",
                                style = EsType.Body,
                                color = SevaInk700,
                            )
                        }
                        Spacer(Modifier.height(8.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun TierHeroCard(d: CertificationStatusRepository.CertificationStatus) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(SevaGreen50)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("Current tier", style = EsType.BodySm, color = SevaInk700)
            Pill(text = d.currentTierLabel, kind = certificationTierPillKind(d.currentTier))
        }
        Text(
            d.currentTierLabel,
            style = EsType.H3.copy(fontWeight = FontWeight.Bold),
            color = SevaGreen700,
        )
        Text(
            "${d.jobsCompleted} jobs completed · ${formatPercent(d.disputeRatePct)} dispute rate",
            style = EsType.Caption,
            color = SevaInk500,
        )
    }
}

@Composable
private fun NextTierCard(d: CertificationStatusRepository.CertificationStatus) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        if (d.jobsNeededForNext > 0) {
            RequirementRow("Complete ${d.jobsNeededForNext} more job${if (d.jobsNeededForNext == 1) "" else "s"}")
        } else {
            RequirementRow("Job count met")
        }
        d.maxDisputeForNext?.let {
            RequirementRow("Keep dispute rate at or below ${formatPercent(it)}")
        }
        d.minVerifiedForNext?.let {
            RequirementRow("Reach ${it.replaceFirstChar { c -> c.uppercase() }} verification")
        }
    }
}

@Composable
private fun RequirementRow(label: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text("○", color = SevaInk500, style = EsType.Body)
        Text(label, style = EsType.Body, color = SevaInk900)
    }
}

@Composable
private fun SectionHeader(label: String) {
    Text(label, style = EsType.H5, color = SevaInk900, modifier = Modifier.padding(top = 4.dp))
}

@Composable
private fun BenefitRow(label: String, value: String) {
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
        Text(label, style = EsType.Body, color = SevaInk700)
        Text(value, style = EsType.Body.copy(fontWeight = FontWeight.Medium), color = SevaInk900)
    }
}

// ---------------------------------------------------------------------
//  Pinned helpers
// ---------------------------------------------------------------------

/** Tier badge tone. gold → amber (Warn), silver → Info, bronze → Forest,
 *  anything else (incl. "none") → Neutral. */
internal fun certificationTierPillKind(tier: String): PillKind = when (tier.lowercase()) {
    "gold" -> PillKind.Warn
    "silver" -> PillKind.Info
    "bronze" -> PillKind.Forest
    else -> PillKind.Neutral
}

/** Human label for the code-red priority integer (higher = sooner). */
internal fun codeRedPriorityLabel(priority: Int): String = when {
    priority <= 0 -> "Standard queue"
    else -> "Priority $priority"
}

/**
 * Formats a percent value, dropping a redundant decimal (7.0 → "7%",
 * 2.5 → "2.5%"). Rounds to one decimal so a noisy numeric never spills.
 */
internal fun formatPercent(value: Double): String {
    val rounded = kotlin.math.round(value * 10.0) / 10.0
    val s = if (rounded % 1.0 == 0.0) rounded.toLong().toString() else rounded.toString()
    return "$s%"
}
