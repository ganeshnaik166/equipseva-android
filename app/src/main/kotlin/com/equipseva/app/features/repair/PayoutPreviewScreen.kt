package com.equipseva.app.features.repair

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
import androidx.compose.material.icons.outlined.Payments
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
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.repair.PayoutPreviewRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.formatRupees
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
import com.equipseva.app.navigation.Routes
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class PayoutPreviewViewModel @Inject constructor(
    savedState: SavedStateHandle,
    private val repo: PayoutPreviewRepository,
) : ViewModel() {
    private val jobId: String =
        checkNotNull(savedState.get<String>(Routes.PAYOUT_PREVIEW_ARG_JOB_ID)) {
            "PayoutPreviewViewModel requires arg ${Routes.PAYOUT_PREVIEW_ARG_JOB_ID}"
        }

    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val data: PayoutPreviewRepository.PayoutPreview? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload() }

    fun reload() {
        _state.update { it.copy(loading = it.data == null, error = null) }
        viewModelScope.launch {
            repo.fetch(jobId)
                .onSuccess { d -> _state.update { it.copy(loading = false, data = d) } }
                // r1452 — keep loaded data on a transient refresh failure.
                .onFailure { e ->
                    _state.update {
                        if (it.data == null) it.copy(loading = false, error = e.toUserMessage()) else it.copy(loading = false)
                    }
                }
        }
    }
}

/**
 * Engineer payout preview for an assigned job (r1413): the effective payout
 * after the hospital's loyalty commission, the contracted amount, the rate,
 * and a warranty note (warranty ⇒ full payout, 0% commission). Read-only;
 * surfaces engineer_view_hospital_tier(). Reached from the engineer view of
 * the job "Records" section.
 */
@Composable
fun PayoutPreviewScreen(
    onBack: () -> Unit,
    viewModel: PayoutPreviewViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "Payout preview", onBack = onBack)
            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                state.error != null -> EmptyStateView(
                    icon = Icons.Outlined.Payments,
                    title = "Couldn't load payout",
                    subtitle = state.error,
                    ctaLabel = "Try again",
                    onCta = { viewModel.reload() },
                )
                state.data == null -> EmptyStateView(
                    icon = Icons.Outlined.Payments,
                    title = "No payout details",
                    subtitle = "Payout details appear once a price is agreed on this job.",
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
                        PayoutHeroCard(d)
                        DetailRow("Contracted amount", formatRupees(d.contractedAmountRupees))
                        DetailRow("Platform commission", if (d.isWarrantyCovered) "0% (warranty)" else commissionPctLabel(d.commissionRate))
                        DetailRow("Your payout", formatRupees(d.effectivePayoutRupees), emphasise = true)
                        val note = warrantyPayoutNote(d.isWarrantyCovered)
                        if (note.isNotEmpty()) {
                            Text(note, style = EsType.Body, color = SevaInk700)
                        }
                        Spacer(Modifier.height(8.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun PayoutHeroCard(d: PayoutPreviewRepository.PayoutPreview) {
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
            Text("You'll earn", style = EsType.BodySm, color = SevaInk700)
            if (d.isWarrantyCovered) Pill(text = "Warranty", kind = PillKind.Info)
        }
        Text(
            formatRupees(d.effectivePayoutRupees),
            style = EsType.H3.copy(fontWeight = FontWeight.Bold),
            color = SevaGreen700,
        )
        Text("after platform commission", style = EsType.Caption, color = SevaInk500)
    }
}

@Composable
private fun DetailRow(label: String, value: String, emphasise: Boolean = false) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(10.dp))
            .padding(14.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, style = EsType.Body, color = SevaInk700)
        Text(
            value,
            style = if (emphasise) EsType.Body.copy(fontWeight = FontWeight.Bold) else EsType.Body.copy(fontWeight = FontWeight.Medium),
            color = SevaInk900,
        )
    }
}

// ---------------------------------------------------------------------
//  Pinned helpers
// ---------------------------------------------------------------------

/** Commission fraction (0.07) → "7%"; rounds to one decimal, drops trailing .0. */
internal fun commissionPctLabel(fraction: Double): String {
    val pct = fraction * 100.0
    val rounded = kotlin.math.round(pct * 10.0) / 10.0
    val s = if (rounded % 1.0 == 0.0) rounded.toLong().toString() else rounded.toString()
    return "$s%"
}

/** Warranty note shown under the payout, or "" for a normal job. */
internal fun warrantyPayoutNote(isWarranty: Boolean): String =
    if (isWarranty) "This is a warranty job — EquipSeva waives its commission, so you keep the full contracted amount." else ""
