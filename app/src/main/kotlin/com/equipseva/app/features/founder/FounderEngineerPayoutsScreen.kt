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
import androidx.compose.foundation.layout.width
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
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.R
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.core.util.relativeLabel
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
    private val app: android.app.Application,
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
        // Round 434 — CSV export in flight (disables the export button).
        val exporting: Boolean = false,
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
        /**
         * Round 434 — payouts CSV ready at the given absolute path
         * inside the app's cache dir. The screen wraps it in a
         * FileProvider URI and fires Intent.ACTION_SEND so the
         * founder can ship it to email / Drive / their CA.
         */
        data class ShareCsv(val absolutePath: String) : Effect
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
                    // Round 3760 — jobNumber can be null on a legacy row;
                    // same "RPR-${take(6)}" fallback used in the sheets.
                    val jobLabel = payout.jobNumber ?: "RPR-${payout.repairJobId.take(6)}"
                    _effects.emit(Effect.ShowMessage("$jobLabel marked paid."))
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
                    val jobLabel = payout.jobNumber ?: "RPR-${payout.repairJobId.take(6)}"
                    _effects.emit(Effect.ShowMessage("$jobLabel cancelled."))
                    load(initial = false)
                }
                .onFailure { e ->
                    _state.update { it.copy(sheetSaving = false, sheetError = e.toUserMessage()) }
                }
        }
    }

    /**
     * Round 434 — dump every payout row (across all statuses, not just
     * the current filter — month-end accounting wants the full picture)
     * to a CSV in the app's cache directory and emit Effect.ShareCsv
     * so the screen wraps it in a FileProvider URI + chooser intent.
     */
    fun exportCsv() {
        if (_state.value.exporting) return
        _state.update { it.copy(exporting = true) }
        viewModelScope.launch {
            // Pull max-allowed window so the export is comprehensive.
            // The 500-row cap on admin_list matches the RPC limit.
            repo.adminListEngineerPayouts(statusFilter = "all", limit = 500)
                .onSuccess { rows ->
                    val csv = formatPayoutsCsv(rows)
                    val filename = csvFilename(System.currentTimeMillis())
                    val path = writeCsvToCache(app, filename, csv)
                    _state.update { it.copy(exporting = false) }
                    _effects.emit(Effect.ShareCsv(path))
                }
                .onFailure { e ->
                    _state.update {
                        it.copy(exporting = false, errorMessage = e.toUserMessage())
                    }
                }
        }
    }
}

/* ---------------------------- round 434: CSV ---------------------------- */

internal fun formatPayoutsCsv(
    rows: List<FounderRepository.AdminEngineerPayout>,
): String {
    val sb = StringBuilder()
    sb.append("job_number,engineer_name,engineer_phone,amount_rupees,status,mode,utr,destination,queued_at,processed_at,failure_reason,attempts\n")
    rows.forEach { r ->
        val rupees = String.format(java.util.Locale.ENGLISH, "%.2f", r.amountPaise / 100.0)
        // Round 3760 — jobNumber can be null on a legacy row; without a
        // repair_job_id column in this export, a blank cell here would
        // leave the row completely unidentifiable to the founder's CA.
        sb.append(csvField(r.jobNumber ?: "RPR-${r.repairJobId.take(6)}")).append(',')
        sb.append(csvField(r.engineerName)).append(',')
        sb.append(csvField(r.engineerPhone)).append(',')
        sb.append(rupees).append(',')
        sb.append(csvField(r.status)).append(',')
        sb.append(csvField(r.mode)).append(',')
        sb.append(csvField(r.utr)).append(',')
        sb.append(csvField(r.destinationLabel)).append(',')
        sb.append(csvField(r.queuedAt)).append(',')
        sb.append(csvField(r.processedAt)).append(',')
        sb.append(csvField(r.failureReason)).append(',')
        sb.append(r.attempts).append('\n')
    }
    return sb.toString()
}

/**
 * RFC 4180-ish CSV field escape: wrap in double quotes when the
 * value contains a comma, quote, newline, or carriage return. Inner
 * quotes are doubled. Nulls render as empty (not the literal word
 * "null") so importers don't surface "null" as a string value.
 */
internal fun csvField(value: String?): String {
    if (value == null) return ""
    val needsQuote = value.any { it == ',' || it == '"' || it == '\n' || it == '\r' }
    if (!needsQuote) return value
    val escaped = value.replace("\"", "\"\"")
    return "\"$escaped\""
}

/**
 * `engineer-payouts-2026-06-03.csv` — date-prefixed so multiple
 * exports stack visibly in the share/save chooser. Uses UTC so the
 * filename is stable across devices in different timezones (the row
 * timestamps inside are also UTC per Postgres convention).
 */
internal fun csvFilename(nowMs: Long): String {
    val fmt = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.ENGLISH)
    fmt.timeZone = java.util.TimeZone.getTimeZone("UTC")
    return "engineer-payouts-${fmt.format(java.util.Date(nowMs))}.csv"
}

private fun writeCsvToCache(
    ctx: android.content.Context,
    filename: String,
    csv: String,
): String {
    val dir = java.io.File(ctx.cacheDir, "exports").apply { mkdirs() }
    val file = java.io.File(dir, filename)
    file.writeText(csv, Charsets.UTF_8)
    return file.absolutePath
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FounderEngineerPayoutsScreen(
    onBack: () -> Unit,
    onShowMessage: (String) -> Unit,
    viewModel: FounderEngineerPayoutsViewModel = hiltViewModel(),
) {
    val s by viewModel.state.collectAsStateWithLifecycle()
    val context = androidx.compose.ui.platform.LocalContext.current

    LaunchedEffect(viewModel) {
        viewModel.effects.collect { e ->
            when (e) {
                is FounderEngineerPayoutsViewModel.Effect.ShowMessage -> onShowMessage(e.text)
                is FounderEngineerPayoutsViewModel.Effect.ShareCsv -> shareCsvFile(context, e.absolutePath)
            }
        }
    }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(
                title = "Engineer payouts",
                onBack = onBack,
                right = {
                    androidx.compose.material3.TextButton(
                        onClick = viewModel::exportCsv,
                        enabled = !s.exporting && !s.loading,
                    ) {
                        Text(
                            if (s.exporting) {
                                stringResource(R.string.founder_payouts_exporting)
                            } else {
                                stringResource(R.string.founder_payouts_export_csv)
                            },
                        )
                    }
                },
            )
            FilterChipsRow(
                selected = s.filter,
                onSelect = viewModel::onFilterSelect,
            )
            // (#18) Error banner with retry — promoted from a tiny
            // line above the list to a proper banner with action so the
            // founder can recover without leaving the screen.
            if (s.errorMessage != null) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(SevaWarning50)
                        .padding(horizontal = 16.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        s.errorMessage.orEmpty(),
                        color = SevaDanger500,
                        fontSize = 13.sp,
                        modifier = Modifier.weight(1f),
                    )
                    Spacer(Modifier.width(8.dp))
                    EsBtn(
                        text = "Retry",
                        onClick = viewModel::onRefresh,
                        kind = EsBtnKind.Secondary,
                    )
                }
            }
            when {
                s.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                s.rows.isEmpty() -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    // (#17) Mention the active filter so the founder
                    // doesn't think every payout dropped — they're just
                    // filtered out.
                    val filterPhrase = when (s.filter) {
                        FounderEngineerPayoutsViewModel.StatusFilter.All -> "across all statuses"
                        else -> "in ${s.filter.label}"
                    }
                    EmptyStateView(
                        icon = Icons.Outlined.Inbox,
                        title = "No payouts $filterPhrase",
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
                    // Round 3760 — repair_jobs.job_number can be null on
                    // a legacy row; same fallback convention as the sheets.
                    row.jobNumber ?: "RPR-${row.repairJobId.take(6)}",
                    fontSize = 13.sp,
                    color = SevaInk500,
                    fontWeight = FontWeight.Medium,
                )
                Text(
                    stringResource(
                        R.string.founder_payouts_amount_arrow_engineer,
                        formatRupees(amountRupees),
                        row.engineerName ?: "Unknown engineer",
                    ),
                    fontSize = 15.sp,
                    color = SevaInk900,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    row.destinationLabel ?: stringResource(R.string.founder_payouts_no_payout_method_short),
                    fontSize = 12.sp,
                    color = SevaInk500,
                )
                // (#20) Age stamp so the founder sees how stale a
                // queued row is at a glance. Use processed_at for
                // settled rows, queued_at otherwise.
                val ageAnchor = row.processedAt ?: row.queuedAt
                val ageLabel = relativeLabel(ageAnchor)
                if (ageLabel != null) {
                    val prefix = when (row.status) {
                        "processed" -> "Paid"
                        "cancelled" -> "Cancelled"
                        else -> "Queued"
                    }
                    Text(
                        stringResource(R.string.founder_payouts_age_stamp, prefix, ageLabel),
                        fontSize = 12.sp,
                        color = SevaInk500,
                    )
                }
                // (#21) Show reason on BOTH failed and cancelled rows
                // (cancelled writes the reason into failure_reason).
                if (!row.failureReason.isNullOrBlank() &&
                    (row.status == "failed" || row.status == "cancelled")) {
                    val tone = if (row.status == "failed") SevaDanger500 else SevaInk500
                    val tag = if (row.status == "failed") "Failed" else "Cancelled"
                    Text(
                        stringResource(R.string.founder_payouts_failure_tag, tag, row.failureReason.orEmpty()),
                        fontSize = 12.sp,
                        color = tone,
                    )
                }
                if (row.status == "processed" && !row.utr.isNullOrBlank()) {
                    Text(
                        stringResource(R.string.repair_payout_utr, row.utr.orEmpty()),
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
    // Round 3760 — repair_jobs.job_number can be null on a legacy row;
    // same "RPR-${take(6)}" fallback convention used elsewhere in the app.
    val jobLabel = p.jobNumber ?: "RPR-${p.repairJobId.take(6)}"
    val context = androidx.compose.ui.platform.LocalContext.current
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
        Text(
            stringResource(R.string.founder_payouts_mark_paid_title),
            fontSize = 18.sp,
            fontWeight = FontWeight.Bold,
            color = SevaInk900,
        )
        Text(
            stringResource(
                R.string.founder_payouts_job_summary_line,
                jobLabel,
                formatRupees(amountRupees),
                p.engineerName ?: "engineer",
            ),
            fontSize = 13.sp,
            color = SevaInk500,
        )
        // Round 435 fix #7 — make the engineer's actual UPI/bank
        // string visible + copyable + GPay-deeplinkable so the
        // founder doesn't have to close the sheet, find the row's
        // destination chip, copy from there, and reopen the sheet
        // every time they settle a row.
        DestinationActionRow(
            destination = p.destinationLabel,
            engineerName = p.engineerName,
            engineerPhone = p.engineerPhone,
            amountRupees = amountRupees,
            jobNumber = jobLabel,
            context = context,
        )
        OutlinedTextField(
            value = state.utr,
            onValueChange = onUtrChange,
            label = { Text(stringResource(R.string.founder_payouts_utr_field_label)) },
            placeholder = { Text(stringResource(R.string.founder_payouts_utr_field_placeholder)) },
            singleLine = true,
            enabled = !state.sheetSaving,
            modifier = Modifier.fillMaxWidth(),
        )
        // Adversarial-review finding #14 — mode as chips, not free text.
        // Free text invited typos ("UPi") that downstream reports would
        // bucket wrong (and silent mismatch with the engineer_payouts.mode
        // CHECK constraint).
        Text(
            stringResource(R.string.founder_payouts_mode_label),
            fontSize = 13.sp,
            color = SevaInk500,
            fontWeight = FontWeight.Medium,
        )
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
            label = { Text(stringResource(R.string.founder_payouts_notes_field_label)) },
            placeholder = { Text(stringResource(R.string.founder_payouts_notes_field_placeholder)) },
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
    // Round 3760 — see MarkPaidSheet's identical fallback comment.
    val jobLabel = p.jobNumber ?: "RPR-${p.repairJobId.take(6)}"
    Column(
        modifier = Modifier
            .fillMaxWidth()
            // Same imePadding fix (#16) for the cancel sheet.
            .imePadding()
            .navigationBarsPadding()
            .padding(horizontal = 20.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(
            stringResource(R.string.founder_payouts_cancel_title),
            fontSize = 18.sp,
            fontWeight = FontWeight.Bold,
            color = SevaInk900,
        )
        Text(
            stringResource(
                R.string.founder_payouts_job_summary_line,
                jobLabel,
                formatRupees(amountRupees),
                p.engineerName ?: "engineer",
            ),
            fontSize = 13.sp,
            color = SevaInk500,
        )
        OutlinedTextField(
            value = state.cancelReason,
            onValueChange = onReasonChange,
            label = { Text(stringResource(R.string.founder_payouts_cancel_reason_label)) },
            placeholder = { Text(stringResource(R.string.founder_payouts_cancel_reason_placeholder)) },
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

private fun shareCsvFile(context: android.content.Context, absolutePath: String) {
    val file = java.io.File(absolutePath)
    val uri = androidx.core.content.FileProvider.getUriForFile(
        context,
        "${context.packageName}.fileprovider",
        file,
    )
    val share = android.content.Intent(android.content.Intent.ACTION_SEND).apply {
        type = "text/csv"
        putExtra(android.content.Intent.EXTRA_STREAM, uri)
        putExtra(android.content.Intent.EXTRA_SUBJECT, "EquipSeva engineer payouts export")
        addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
    val chooser = android.content.Intent.createChooser(share, "Share payouts CSV").apply {
        addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    context.startActivity(chooser)
}

/* ----- round 435 fix #7 — destination copy + GPay deeplink ----- */

@Composable
private fun DestinationActionRow(
    destination: String?,
    engineerName: String?,
    engineerPhone: String?,
    amountRupees: Double,
    jobNumber: String,
    context: android.content.Context,
) {
    if (destination.isNullOrBlank()) {
        Text(
            stringResource(R.string.founder_payouts_no_destination_body),
            fontSize = 12.sp,
            color = SevaDanger500,
        )
        return
    }
    val isUpi = looksLikeVpa(destination)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(SevaGreen50)
            .border(width = 1.dp, color = BorderDefault, shape = RoundedCornerShape(10.dp))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            if (isUpi) stringResource(R.string.founder_payouts_upi_prefix, destination) else destination,
            fontSize = 14.sp,
            color = SevaInk900,
            fontWeight = FontWeight.SemiBold,
        )
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            EsBtn(
                text = "Copy",
                onClick = { copyToClipboard(context, destination, "EquipSeva destination") },
                kind = EsBtnKind.Secondary,
            )
            if (isUpi) {
                EsBtn(
                    text = "Pay via UPI",
                    onClick = {
                        val uri = buildUpiDeeplink(destination, engineerName, amountRupees, jobNumber)
                        openUpiIntent(context, uri)
                    },
                    kind = EsBtnKind.Primary,
                )
            }
            if (!engineerPhone.isNullOrBlank()) {
                EsBtn(
                    text = "Call",
                    onClick = { openTelIntent(context, engineerPhone) },
                    kind = EsBtnKind.Secondary,
                )
            }
        }
    }
}

internal fun looksLikeVpa(s: String): Boolean =
    s.matches(Regex("^[a-zA-Z0-9._-]+@[a-zA-Z]+\$"))

/**
 * UPI deeplink per NPCI spec: upi://pay?pa=<vpa>&pn=<name>&am=<amount>&cu=INR&tn=<note>
 * GPay, PhonePe, Paytm all accept this. Amount as plain rupees decimal
 * (no rounding) — the user can confirm before sending.
 */
internal fun buildUpiDeeplink(
    vpa: String,
    payeeName: String?,
    amountRupees: Double,
    jobNumber: String,
): String {
    val enc: (String) -> String = { java.net.URLEncoder.encode(it, "UTF-8") }
    val amount = String.format(java.util.Locale.ENGLISH, "%.2f", amountRupees)
    val name = enc(payeeName?.takeIf { it.isNotBlank() } ?: "EquipSeva engineer")
    val note = enc("EquipSeva $jobNumber")
    return "upi://pay?pa=${enc(vpa)}&pn=$name&am=$amount&cu=INR&tn=$note"
}

private fun copyToClipboard(context: android.content.Context, value: String, label: String) {
    val clip = context.getSystemService(android.content.Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager
    clip.setPrimaryClip(android.content.ClipData.newPlainText(label, value))
    android.widget.Toast.makeText(context, "Copied", android.widget.Toast.LENGTH_SHORT).show()
}

private fun openUpiIntent(context: android.content.Context, uri: String) {
    val intent = android.content.Intent(android.content.Intent.ACTION_VIEW).apply {
        data = android.net.Uri.parse(uri)
        addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    runCatching { context.startActivity(intent) }.onFailure {
        android.widget.Toast.makeText(
            context,
            "No UPI app installed",
            android.widget.Toast.LENGTH_SHORT,
        ).show()
    }
}

private fun openTelIntent(context: android.content.Context, phone: String) {
    val intent = android.content.Intent(android.content.Intent.ACTION_DIAL).apply {
        data = android.net.Uri.parse("tel:$phone")
        addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    runCatching { context.startActivity(intent) }
}
