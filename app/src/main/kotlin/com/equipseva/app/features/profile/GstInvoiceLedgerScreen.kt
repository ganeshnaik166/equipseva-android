package com.equipseva.app.features.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ReceiptLong
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
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.invoice.FyInvoiceGroup
import com.equipseva.app.core.data.invoice.GstInvoiceLedgerRepository
import com.equipseva.app.core.data.invoice.summariseGstInvoicesByFiscalYear
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.core.util.prettyDate
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen50
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
class GstInvoiceLedgerViewModel @Inject constructor(
    private val repo: GstInvoiceLedgerRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val error: String? = null,
        val groups: List<FyInvoiceGroup> = emptyList(),
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload(initial = true) }

    fun reload(initial: Boolean = false) {
        _state.update {
            it.copy(
                loading = initial || it.groups.isEmpty(),
                refreshing = !initial && it.groups.isNotEmpty(),
                error = null,
            )
        }
        viewModelScope.launch {
            repo.fetchMyInvoices()
                .onSuccess { rows ->
                    _state.update {
                        it.copy(
                            loading = false,
                            refreshing = false,
                            groups = summariseGstInvoicesByFiscalYear(rows),
                        )
                    }
                }
                .onFailure { e ->
                    _state.update {
                        if (it.groups.isEmpty()) it.copy(loading = false, refreshing = false, error = e.toUserMessage())
                        else it.copy(loading = false, refreshing = false)
                    }
                }
        }
    }

    fun onPullToRefresh() = reload(initial = false)
}

/**
 * Read-only GST invoice ledger (incoming + outgoing), grouped by Indian
 * fiscal year with per-FY taxable/GST/total roll-ups. Reachable from the
 * Profile "GST invoices" row for both hospitals and engineers.
 */
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun GstInvoiceLedgerScreen(
    onBack: () -> Unit,
    viewModel: GstInvoiceLedgerViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "GST invoices", onBack = onBack)
            androidx.compose.material3.pulltorefresh.PullToRefreshBox(
                isRefreshing = state.refreshing,
                onRefresh = viewModel::onPullToRefresh,
                modifier = Modifier.fillMaxSize(),
            ) {
                when {
                    state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                    state.error != null -> EmptyStateView(
                        icon = Icons.Outlined.ReceiptLong,
                        title = "Couldn't load invoices",
                        subtitle = state.error,
                        ctaLabel = "Try again",
                        onCta = { viewModel.reload() },
                    )
                    state.groups.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.ReceiptLong,
                        title = "No GST invoices yet",
                        subtitle = "Repair and AMC invoices raised to or by you appear here, grouped by financial year.",
                    )
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(12.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        state.groups.forEach { group ->
                            item(key = "fy-${group.fiscalYearLabel}") { FyHeaderCard(group) }
                            items(group.rows, key = { it.id }) { row -> InvoiceRow(row) }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun FyHeaderCard(group: FyInvoiceGroup) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(SevaGreen50)
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(group.fiscalYearLabel, color = SevaInk900, fontWeight = FontWeight.Bold, fontSize = 15.sp)
            Text(
                "${group.invoiceCount} invoice${if (group.invoiceCount == 1) "" else "s"}",
                color = SevaInk500,
                fontSize = 12.sp,
            )
        }
        Text(
            "Taxable ${formatRupees(group.taxableRupees)} · GST ${formatRupees(group.gstRupees)} · " +
                "Total ${formatRupees(group.totalRupees)}",
            color = SevaInk700,
            fontSize = 12.sp,
            fontWeight = FontWeight.Medium,
        )
        Text(
            "${group.incomingCount} incoming · ${group.outgoingCount} outgoing" +
                if (group.rcmCount > 0) " · ${group.rcmCount} RCM" else "",
            color = SevaInk500,
            fontSize = 11.sp,
        )
    }
}

@Composable
private fun InvoiceRow(row: GstInvoiceLedgerRepository.GstInvoiceRow) {
    val (pillText, pillKind) = invoiceDirectionPill(row.direction)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Column(modifier = Modifier.weight(1f)) {
                Text(row.invoiceSerial, color = SevaInk900, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                Text(
                    row.counterpartyName?.takeIf { it.isNotBlank() } ?: "—",
                    color = SevaInk700,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium,
                )
            }
            Pill(text = pillText, kind = pillKind)
        }
        Text(
            "${formatRupees(row.totalInvoiceRupees)} · ${prettyDate(row.issuedAt)}",
            color = SevaInk700,
            fontSize = 12.sp,
        )
        if (row.rcmApplicable) {
            Text("Reverse charge (RCM)", color = SevaInk500, fontSize = 11.sp)
        }
    }
    Spacer(Modifier.height(0.dp))
}

/**
 * Direction pill for an invoice row. "outgoing" (the user issued it) reads
 * Forest/green; "incoming" (a bill to the user) reads Info; any future
 * direction string capitalises with a Neutral tone (defensive default).
 */
internal fun invoiceDirectionPill(direction: String): Pair<String, PillKind> = when (direction) {
    "outgoing" -> "Outgoing" to PillKind.Forest
    "incoming" -> "Incoming" to PillKind.Info
    else -> direction.replaceFirstChar { it.uppercase() } to PillKind.Neutral
}
