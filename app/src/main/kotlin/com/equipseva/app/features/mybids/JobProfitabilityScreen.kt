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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Calculate
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.repair.ProfitabilityRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsField
import com.equipseva.app.designsystem.components.EsFieldType
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
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class JobProfitabilityViewModel @Inject constructor(
    private val repo: ProfitabilityRepository,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {
    // Nav arg key — matches Routes.JOB_PROFITABILITY_ARG_BID_ID ("bidId").
    private val bidId: String = savedStateHandle.get<String>("bidId").orEmpty()

    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val data: ProfitabilityRepository.BidProfitability? = null,
        val floorInput: String = "",
        val saving: Boolean = false,
    ) {
        val floorError: String? get() = profitabilityFloorError(floorInput)
        val canSaveFloor: Boolean get() = floorInput.isNotBlank() && floorError == null && !saving
    }

    sealed interface Effect {
        data class ShowMessage(val text: String) : Effect
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()
    private val _effects = MutableSharedFlow<Effect>(extraBufferCapacity = 4)
    val effects: Flow<Effect> = _effects

    init { load() }

    fun reload() = load()

    private fun load() {
        _state.update { it.copy(loading = it.data == null, error = null) }
        viewModelScope.launch {
            if (bidId.isBlank()) {
                _state.update { it.copy(loading = false, error = "Missing bid reference.") }
                return@launch
            }
            repo.fetchForBid(bidId)
                .onSuccess { d ->
                    _state.update {
                        it.copy(
                            loading = false,
                            data = d,
                            // Seed the floor field once from the server value.
                            floorInput = if (it.floorInput.isBlank() && d != null) {
                                d.profitabilityFloorRupees.toLong().toString()
                            } else {
                                it.floorInput
                            },
                        )
                    }
                }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.toUserMessage()) } }
        }
    }

    fun onFloorChange(v: String) = _state.update { it.copy(floorInput = v) }

    fun onSaveFloor() {
        val s = _state.value
        if (!s.canSaveFloor) return
        val value = s.floorInput.trim().toDoubleOrNull() ?: return
        viewModelScope.launch {
            _state.update { it.copy(saving = true) }
            repo.setFloor(value)
                .onSuccess {
                    _state.update { it.copy(saving = false) }
                    _effects.tryEmit(Effect.ShowMessage("Floor updated to ${formatRupees(value)}"))
                    load() // re-fetch so the net-pay flag reflects the new floor
                }
                .onFailure { e ->
                    _state.update { it.copy(saving = false) }
                    _effects.tryEmit(Effect.ShowMessage(e.toUserMessage()))
                }
        }
    }
}

/**
 * Net-pay estimate for one repair bid: gross minus platform fee, GST on the
 * fee, a TDS estimate and round-trip travel, with a "below your floor" flag
 * and an editable floor. Reached from a bid card in My Bids.
 */
@Composable
fun JobProfitabilityScreen(
    onBack: () -> Unit,
    onShowMessage: (String) -> Unit,
    viewModel: JobProfitabilityViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    androidx.compose.runtime.LaunchedEffect(viewModel) {
        viewModel.effects.collect { eff ->
            when (eff) {
                is JobProfitabilityViewModel.Effect.ShowMessage -> onShowMessage(eff.text)
            }
        }
    }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "Net pay estimate", onBack = onBack)
            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                state.error != null || state.data == null -> EmptyStateView(
                    icon = Icons.Outlined.Calculate,
                    title = "Couldn't estimate net pay",
                    subtitle = state.error ?: "No estimate available for this bid.",
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
                        NetPayCard(d)
                        FloorEditorCard(
                            value = state.floorInput,
                            error = state.floorError,
                            saving = state.saving,
                            canSave = state.canSaveFloor,
                            onChange = viewModel::onFloorChange,
                            onSave = viewModel::onSaveFloor,
                        )
                        Text(
                            "Estimate only. Travel assumes a round trip at ₹4/km from your saved base; " +
                                "TDS is a 1% estimate that applies once your yearly gross crosses ₹5,00,000.",
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
private fun NetPayCard(d: ProfitabilityRepository.BidProfitability) {
    val (badgeText, badgeKind) = profitBadgeTextAndKind(d.belowFloor)
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
            Text("Estimated net pay", style = EsType.BodySm, color = SevaInk700)
            Pill(text = badgeText, kind = badgeKind)
        }
        Text(
            formatRupees(d.estimatedNetRupees),
            style = EsType.H3.copy(fontWeight = FontWeight.Bold),
            color = SevaGreen700,
        )
        Spacer(Modifier.height(6.dp))
        BreakdownRow("Gross bid", d.grossBidRupees, deduction = false)
        BreakdownRow("Platform fee (7%)", d.platformFeeRupees, deduction = true)
        BreakdownRow("TDS estimate", d.tdsEstimateRupees, deduction = true)
        BreakdownRow(travelLabel(d.distanceKm), d.estimatedTravelCostRupees, deduction = true)
        Box(Modifier.fillMaxWidth().height(1.dp).background(BorderDefault))
        BreakdownRow("Estimated net", d.estimatedNetRupees, deduction = false, emphasise = true)
        // GST on the fee is billed to the hospital under reverse-charge (RCM) —
        // it never comes out of the engineer's payout. Previously it sat in the
        // deduction stack above with a "−", so the subtracted lines appeared to
        // under-total Estimated net by exactly the GST. Show it as an info
        // footnote instead, so the deductions foot exactly to net.
        Spacer(Modifier.height(6.dp))
        Text(
            "GST on fee (${formatRupees(d.gstOnFeeRupees)}) is billed to the hospital under RCM — not deducted from your payout.",
            style = EsType.Caption,
            color = SevaInk500,
        )
    }
}

@Composable
private fun BreakdownRow(label: String, amount: Double, deduction: Boolean, emphasise: Boolean = false) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            label,
            style = if (emphasise) EsType.Body.copy(fontWeight = FontWeight.SemiBold) else EsType.BodySm,
            color = if (emphasise) SevaInk900 else SevaInk700,
        )
        Text(
            (if (deduction) "− " else "") + formatRupees(amount),
            style = if (emphasise) EsType.Body.copy(fontWeight = FontWeight.SemiBold) else EsType.BodySm,
            color = if (emphasise) SevaInk900 else SevaInk700,
        )
    }
}

@Composable
private fun FloorEditorCard(
    value: String,
    error: String?,
    saving: Boolean,
    canSave: Boolean,
    onChange: (String) -> Unit,
    onSave: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text("Your net-pay floor", style = EsType.Body.copy(fontWeight = FontWeight.SemiBold), color = SevaInk900)
        Text(
            "Bids whose estimated net falls below this are flagged so you don't accept an unprofitable job.",
            style = EsType.Caption,
            color = SevaInk500,
        )
        EsField(
            value = value,
            onChange = onChange,
            label = "Floor (₹)",
            placeholder = "e.g. 1500",
            error = error,
            type = EsFieldType.Number,
            enabled = !saving,
            imeAction = ImeAction.Done,
            onImeAction = { if (canSave) onSave() },
        )
        EsBtn(
            text = if (saving) "Saving…" else "Save floor",
            onClick = onSave,
            kind = EsBtnKind.Primary,
            size = EsBtnSize.Md,
            full = true,
            disabled = !canSave,
        )
    }
}

// ---------------------------------------------------------------------
//  Pinned helpers
// ---------------------------------------------------------------------

private fun travelLabel(distanceKm: Double?): String =
    if (distanceKm != null) "Travel (round trip · ${formatKm(distanceKm)} km)" else "Travel (round trip)"

private fun formatKm(km: Double): String =
    if (km == km.toLong().toDouble()) km.toLong().toString() else String.format(java.util.Locale.ROOT, "%.1f", km)

/**
 * Net-pay badge for the estimate. below_floor is computed server-side against
 * the engineer's saved floor; this maps it to display copy + tone.
 */
internal fun profitBadgeTextAndKind(belowFloor: Boolean): Pair<String, PillKind> =
    if (belowFloor) "Below your floor" to PillKind.Danger else "Above your floor" to PillKind.Success

/**
 * Client-side validation for the net-pay floor, mirroring the server clamp
 * (0..50000). Blank → null (submit gates on isNotBlank); non-numeric or
 * out-of-range → a friendly message.
 */
internal fun profitabilityFloorError(input: String): String? {
    val trimmed = input.trim()
    if (trimmed.isEmpty()) return null
    val v = trimmed.toDoubleOrNull() ?: return "Enter a number."
    if (v < 0) return "Floor can't be negative."
    if (v > 50000) return "Floor can't exceed ₹50,000."
    return null
}
