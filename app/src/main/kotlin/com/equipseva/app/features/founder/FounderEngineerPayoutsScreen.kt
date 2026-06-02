package com.equipseva.app.features.founder

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Inbox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.designsystem.theme.SevaWarning50
import com.equipseva.app.designsystem.theme.SevaWarning500
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * Round 428. Founder-only admin screen to drain the engineer_payouts
 * queue manually during the RazorpayX-less period (waiting on GST cert,
 * RazorpayX KYC, etc) and to handle edge cases after activation.
 *
 * Per row: tap → bottom sheet with two actions:
 *  - Mark paid (UTR + mode + notes; flips status='processed', stamps
 *    UTR so engineer's Earnings screen reads "Paid · UTR <utr>")
 *  - Cancel (reason min 5 chars; flips status='cancelled')
 *
 * Filter chips: All / Queued / Processing / Processed / Failed / Cancelled.
 * Default = All. The list pre-sorts action-required statuses to top
 * server-side (admin_list_engineer_payouts), so within the All filter
 * the founder lands on queued/processing rows immediately.
 */
@HiltViewModel
class FounderEngineerPayoutsViewModel @Inject constructor(
    private val repo: FounderRepository,
) : ViewModel() {

    enum class StatusFilter(val rpcParam: String?, val label: String) {
        All(null, "All"),
        Queued("queued", "Queued"),
        Processing("processing", "Processing"),
        Failed("failed", "Failed"),
        Processed("processed", "Paid"),
        Cancelled("cancelled", "Cancelled"),
    }

    enum class SheetMode { MarkPaid, Cancel }

    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val filter: StatusFilter = StatusFilter.All,
        val rows: List<FounderRepository.AdminEngineerPayout> = emptyList(),
        val errorMessage: String? = null,
        // Sheet state.
        val sheetPayout: FounderRepository.AdminEngineerPayout? = null,
        val sheetMode: SheetMode = SheetMode.MarkPaid,
        val sheetSaving: Boolean = false,
        val sheetError: String? = null,
        // MarkPaid form.
        val utr: String = "",
        val mode: String = "UPI",
        val notes: String = "",
        // Cancel form.
        val cancelReason: String = "",
    ) {
        val canMarkPaid: Boolean
            // Adversarial-review finding #13 — require UTR for real-money
            // marking-paid. UTR is the only forensic anchor when the
            // engineer's earnings screen shows "Paid · UTR <utr>".
            // Without UTR a typo'd mark-paid leaves no way to chase up.
            get() = !sheetSaving && sheetPayout != null &&
                mode.isNotBlank() && utr.trim().length >= 6
        val canCancel: Boolean
            get() = !sheetSaving && cancelReason.trim().length >= 5
    }

    sealed interface Effect {
        data class ShowMessage(val text: String) : Effect
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private val _effects = MutableSharedFlow<Effect>(extraBufferCapacity = 4)
    val effects: kotlinx.coroutines.flow.Flow<Effect> = _effects

    init {
        load(initial = true)
    }

    fun onFilterSelect(f: StatusFilter) {
        if (f == _state.value.filter) return
        _state.update { it.copy(filter = f, loading = true, errorMessage = null) }
        load(initial = true)
    }

    fun onRefresh() = load(initial = false)

    private fun load(initial: Boolean) {
        _state.update { it.copy(loading = initial, refreshing = !initial, errorMessage = null) }
        viewModelScope.launch {
            val filter = _state.value.filter.rpcParam
            repo.adminListEngineerPayouts(statusFilter = filter)
                .onSuccess { rows ->
                    _state.update {
                        it.copy(loading = false, refreshing = false, rows = rows, errorMessage = null)
                    }
                }
                .onFailure { e ->
                    _state.update {
                        it.copy(loading = false, refreshing = false, errorMessage = e.toUserMessage())
                    }
                }
        }
    }

    fun openMarkPaid(row: FounderRepository.AdminEngineerPayout) {
        _state.update {
            it.copy(
                sheetPayout = row,
                sheetMode = SheetMode.MarkPaid,
                sheetError = null,
                utr = "",
                mode = "UPI",
                notes = "",
            )
        }
    }

    fun openCancel(row: FounderRepository.AdminEngineerPayout) {
        _state.update {
            it.copy(
                sheetPayout = row,
                sheetMode = SheetMode.Cancel,
                sheetError = null,
                cancelReason = "",
            )
        }
    }

    fun closeSheet() {
        _state.update {
            it.copy(sheetPayout = null, sheetSaving = false, sheetError = null)
        }
    }

    fun onUtrChange(v: String) = _state.update { it.copy(utr = v, sheetError = null) }
    fun onModeChange(v: String) = _state.update { it.copy(mode = v, sheetError = null) }
    fun onNotesChange(v: String) = _state.update { it.copy(notes = v) }
    fun onCancelReasonChange(v: String) = _state.update { it.copy(cancelReason = v, sheetError = null) }

    fun submitMarkPaid() {
        val s = _state.value
        val payout = s.sheetPayout ?: return
        if (!s.canMarkPaid) return
        _state.update { it.copy(sheetSaving = true, sheetError = null) }
        viewModelScope.launch {
            repo.adminMarkPayoutPaid(
                payoutId = payout.id,
                utr = s.utr.takeIf { it.isNotBlank() },
                mode = s.mode.takeIf { it.isNotBlank() },
                notes = s.notes.takeIf { it.isNotBlank() },
            )
                .onSuccess {
                    _state.update { it.copy(sheetSaving = false, sheetPayout = null) }
                    _effects.emit(Effect.ShowMessage("${payout.jobNumber} marked paid."))
                    load(initial = false)
                }
                .onFailure { e ->
                    _state.update { it.copy(sheetSaving = false, sheetError = e.toUserMessage()) }
                }
        }
    }

    fun submitCancel() {
        val s = _state.value
        val payout = s.sheetPayout ?: return
        if (!s.canCancel) return
        _state.update { it.copy(sheetSaving = true, sheetError = null) }
        viewModelScope.launch {
            repo.adminCancelPayout(payoutId = payout.id, reason = s.cancelReason.trim())
                .onSuccess {
                    _state.update { it.copy(sheetSaving = false, sheetPayout = null) }
                    _effects.emit(Effect.ShowMessage("${payout.jobNumber} cancelled."))
                    load(initial = false)
                }
                .onFailure { e ->
                    _state.update { it.copy(sheetSaving = false, sheetError = e.toUserMessage()) }
                }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FounderEngineerPayoutsScreen(
    onBack: () -> Unit,
    onShowMessage: (String) -> Unit,
    viewModel: FounderEngineerPayoutsViewModel = hiltViewModel(),
) {
    val s by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(viewModel) {
        viewModel.effects.collect { e ->
            when (e) {
                is FounderEngineerPayoutsViewModel.Effect.ShowMessage -> onShowMessage(e.text)
            }
        }
    }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "Engineer payouts", onBack = onBack)
            FilterChipsRow(
                selected = s.filter,
                onSelect = viewModel::onFilterSelect,
            )
            if (s.errorMessage != null) {
                Text(
                    s.errorMessage.orEmpty(),
                    color = SevaDanger500,
                    fontSize = 13.sp,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                )
            }
            when {
                s.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                s.rows.isEmpty() -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    EmptyStateView(
                        icon = Icons.Outlined.Inbox,
                        title = "No payouts here",
                        subtitle = "Try a different filter or wait for the next escrow release.",
                    )
                }
                else -> LazyColumn(modifier = Modifier.fillMaxSize()) {
                    items(s.rows, key = { it.id }) { row ->
                        // Adversarial-review finding #9/#12 — only
                        // actionable statuses open the sheet. Tapping a
                        // processed / cancelled row is a no-op (read-
                        // only display); the founder isn't tempted to
                        // submit a mark-paid that the RPC would silently
                        // dedupe.
                        val isActionable = row.status in setOf("queued", "failed")
                        PayoutAdminRow(
                            row = row,
                            onOpen = if (isActionable) {
                                { viewModel.openMarkPaid(row) }
                            } else null,
                        )
                    }
                }
            }
        }
    }

    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    if (s.sheetPayout != null) {
        ModalBottomSheet(
            onDismissRequest = viewModel::closeSheet,
            sheetState = sheetState,
        ) {
            when (s.sheetMode) {
                FounderEngineerPayoutsViewModel.SheetMode.MarkPaid ->
                    MarkPaidSheet(
                        state = s,
                        onUtrChange = viewModel::onUtrChange,
                        onModeChange = viewModel::onModeChange,
                        onNotesChange = viewModel::onNotesChange,
                        onSwitchToCancel = { viewModel.openCancel(s.sheetPayout!!) },
                        onSubmit = viewModel::submitMarkPaid,
                        onDismiss = viewModel::closeSheet,
                    )
                FounderEngineerPayoutsViewModel.SheetMode.Cancel ->
                    CancelPayoutSheet(
                        state = s,
                        onReasonChange = viewModel::onCancelReasonChange,
                        onBackToMarkPaid = { viewModel.openMarkPaid(s.sheetPayout!!) },
                        onSubmit = viewModel::submitCancel,
                        onDismiss = viewModel::closeSheet,
                    )
            }
        }
    }
}

@Composable
private fun FilterChipsRow(
    selected: FounderEngineerPayoutsViewModel.StatusFilter,
    onSelect: (FounderEngineerPayoutsViewModel.StatusFilter) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = 12.dp, vertical = 10.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        FounderEngineerPayoutsViewModel.StatusFilter.entries.forEach { f ->
            FilterChip(
                label = f.label,
                selected = f == selected,
                onClick = { onSelect(f) },
            )
        }
    }
}

@Composable
private fun FilterChip(label: String, selected: Boolean, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(999.dp))
            .background(if (selected) SevaGreen50 else PaperDefault)
            .border(
                width = 1.dp,
                color = if (selected) SevaGreen700 else BorderDefault,
                shape = RoundedCornerShape(999.dp),
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 8.dp),
    ) {
        Text(
            label,
            color = if (selected) SevaGreen700 else SevaInk500,
            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Medium,
            fontSize = 13.sp,
        )
    }
}

@Composable
private fun PayoutAdminRow(
    row: FounderRepository.AdminEngineerPayout,
    onOpen: (() -> Unit)?,
) {
    val amountRupees = row.amountPaise / 100.0
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .let { m -> if (onOpen != null) m.clickable(onClick = onOpen) else m }
            .padding(horizontal = 16.dp, vertical = 12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    row.jobNumber,
                    fontSize = 13.sp,
                    color = SevaInk500,
                    fontWeight = FontWeight.Medium,
                )
                Text(
                    "₹${formatRupees(amountRupees)} → ${row.engineerName ?: "Unknown engineer"}",
                    fontSize = 15.sp,
                    color = SevaInk900,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    row.destinationLabel ?: "No payout method on file",
                    fontSize = 12.sp,
                    color = SevaInk500,
                )
                if (!row.failureReason.isNullOrBlank() && row.status == "failed") {
                    Text(
                        row.failureReason.orEmpty(),
                        fontSize = 12.sp,
                        color = SevaDanger500,
                    )
                }
                if (row.status == "processed" && !row.utr.isNullOrBlank()) {
                    Text(
                        "Paid · UTR ${row.utr}",
                        fontSize = 12.sp,
                        color = SevaGreen700,
                    )
                }
            }
            AdminStatusPill(row.status)
        }
    }
}

@Composable
private fun AdminStatusPill(status: String) {
    val (label, bg, fg) = when (status) {
        "queued" -> Triple("Queued", SevaWarning50, SevaWarning500)
        "processing" -> Triple("Processing", SevaWarning50, SevaWarning500)
        "processed" -> Triple("Paid", SevaGreen50, SevaGreen700)
        "failed" -> Triple("Failed", SevaWarning50, SevaDanger500)
        "cancelled" -> Triple("Cancelled", SevaWarning50, SevaInk500)
        else -> Triple(status, SevaWarning50, SevaInk500)
    }
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(999.dp))
            .background(bg)
            .padding(horizontal = 10.dp, vertical = 4.dp),
    ) {
        Text(label, fontSize = 11.sp, color = fg, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun ModeChip(label: String, selected: Boolean, enabled: Boolean, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(999.dp))
            .background(if (selected) SevaGreen50 else PaperDefault)
            .border(
                width = 1.dp,
                color = if (selected) SevaGreen700 else BorderDefault,
                shape = RoundedCornerShape(999.dp),
            )
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 6.dp),
    ) {
        Text(
            label,
            color = if (selected) SevaGreen700 else SevaInk500,
            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Medium,
            fontSize = 13.sp,
        )
    }
}

@Composable
private fun MarkPaidSheet(
    state: FounderEngineerPayoutsViewModel.UiState,
    onUtrChange: (String) -> Unit,
    onModeChange: (String) -> Unit,
    onNotesChange: (String) -> Unit,
    onSwitchToCancel: () -> Unit,
    onSubmit: () -> Unit,
    onDismiss: () -> Unit,
) {
    val p = state.sheetPayout ?: return
    val amountRupees = p.amountPaise / 100.0
    Column(
        modifier = Modifier
            .fillMaxWidth()
            // Adversarial-review finding #16 — keep form fields above the
            // keyboard + nav bar so the founder can see what they're
            // about to submit.
            .imePadding()
            .navigationBarsPadding()
            .padding(horizontal = 20.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("Mark paid", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = SevaInk900)
        Text(
            "${p.jobNumber} · ₹${formatRupees(amountRupees)} → ${p.engineerName ?: "engineer"} (${p.destinationLabel ?: "no method"})",
            fontSize = 13.sp,
            color = SevaInk500,
        )
        OutlinedTextField(
            value = state.utr,
            onValueChange = onUtrChange,
            label = { Text("UTR / Reference (required, min 6 chars)") },
            placeholder = { Text("e.g. 426012345678") },
            singleLine = true,
            enabled = !state.sheetSaving,
            modifier = Modifier.fillMaxWidth(),
        )
        // Adversarial-review finding #14 — mode as chips, not free text.
        // Free text invited typos ("UPi") that downstream reports would
        // bucket wrong (and silent mismatch with the engineer_payouts.mode
        // CHECK constraint).
        Text("Mode", fontSize = 13.sp, color = SevaInk500, fontWeight = FontWeight.Medium)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf("UPI", "IMPS", "NEFT", "cash", "other").forEach { opt ->
                ModeChip(
                    label = opt,
                    selected = state.mode == opt,
                    enabled = !state.sheetSaving,
                    onClick = { onModeChange(opt) },
                )
            }
        }
        OutlinedTextField(
            value = state.notes,
            onValueChange = onNotesChange,
            label = { Text("Notes (founder-only audit)") },
            placeholder = { Text("e.g. Sent via GPay from personal account") },
            enabled = !state.sheetSaving,
            modifier = Modifier.fillMaxWidth(),
        )
        if (state.sheetError != null) {
            Text(state.sheetError.orEmpty(), color = SevaDanger500, fontSize = 13.sp)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            EsBtn(
                text = "Cancel instead",
                onClick = onSwitchToCancel,
                kind = EsBtnKind.Ghost,
                disabled = state.sheetSaving,
            )
            EsBtn(
                text = "Close",
                onClick = onDismiss,
                kind = EsBtnKind.Secondary,
                disabled = state.sheetSaving,
            )
            EsBtn(
                text = if (state.sheetSaving) "Saving…" else "Mark paid",
                onClick = onSubmit,
                kind = EsBtnKind.Primary,
                disabled = !state.canMarkPaid,
            )
        }
        Spacer(Modifier.height(8.dp))
    }
}

@Composable
private fun CancelPayoutSheet(
    state: FounderEngineerPayoutsViewModel.UiState,
    onReasonChange: (String) -> Unit,
    onBackToMarkPaid: () -> Unit,
    onSubmit: () -> Unit,
    onDismiss: () -> Unit,
) {
    val p = state.sheetPayout ?: return
    val amountRupees = p.amountPaise / 100.0
    Column(
        modifier = Modifier
            .fillMaxWidth()
            // Same imePadding fix (#16) for the cancel sheet.
            .imePadding()
            .navigationBarsPadding()
            .padding(horizontal = 20.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("Cancel payout", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = SevaInk900)
        Text(
            "${p.jobNumber} · ₹${formatRupees(amountRupees)} → ${p.engineerName ?: "engineer"}",
            fontSize = 13.sp,
            color = SevaInk500,
        )
        OutlinedTextField(
            value = state.cancelReason,
            onValueChange = onReasonChange,
            label = { Text("Reason (min 5 chars)") },
            placeholder = { Text("e.g. dispute resolved against engineer; no payout due") },
            enabled = !state.sheetSaving,
            modifier = Modifier.fillMaxWidth(),
        )
        if (state.sheetError != null) {
            Text(state.sheetError.orEmpty(), color = SevaDanger500, fontSize = 13.sp)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            EsBtn(
                text = "Back to mark-paid",
                onClick = onBackToMarkPaid,
                kind = EsBtnKind.Ghost,
                disabled = state.sheetSaving,
            )
            EsBtn(
                text = "Close",
                onClick = onDismiss,
                kind = EsBtnKind.Secondary,
                disabled = state.sheetSaving,
            )
            EsBtn(
                text = if (state.sheetSaving) "Cancelling…" else "Cancel payout",
                onClick = onSubmit,
                kind = EsBtnKind.Danger,
                disabled = !state.canCancel,
            )
        }
        Spacer(Modifier.height(8.dp))
    }
}
