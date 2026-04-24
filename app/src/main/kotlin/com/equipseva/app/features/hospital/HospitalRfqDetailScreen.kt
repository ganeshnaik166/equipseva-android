package com.equipseva.app.features.hospital

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.RequestQuote
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.data.rfq.Rfq
import com.equipseva.app.core.data.rfq.RfqBid
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.core.util.relativeLabel
import com.equipseva.app.designsystem.components.BidCard
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.PrimaryButton
import com.equipseva.app.designsystem.components.SectionHeader
import com.equipseva.app.designsystem.components.StatusChip
import com.equipseva.app.designsystem.components.StatusTone
import com.equipseva.app.designsystem.components.TonalButton
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.designsystem.theme.Surface50
import java.time.Instant

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HospitalRfqDetailScreen(
    onBack: () -> Unit,
    onNavigateToChat: (String) -> Unit = {},
    viewModel: HospitalRfqDetailViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val snackbarHost = remember { SnackbarHostState() }

    LaunchedEffect(Unit) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is HospitalRfqDetailViewModel.Effect.ShowMessage ->
                    snackbarHost.showSnackbar(effect.text)
                is HospitalRfqDetailViewModel.Effect.NavigateToChat ->
                    onNavigateToChat(effect.conversationId)
            }
        }
    }

    Scaffold(
        topBar = { ESBackTopBar(title = "RFQ details", onBack = onBack) },
        snackbarHost = { SnackbarHost(snackbarHost) },
        containerColor = Surface50,
    ) { inner ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(inner),
        ) {
            ErrorBanner(
                message = state.errorMessage,
                modifier = Modifier.padding(horizontal = Spacing.lg),
            )
            PullToRefreshBox(
                isRefreshing = state.refreshing,
                onRefresh = viewModel::onRefresh,
                modifier = Modifier.fillMaxSize(),
            ) {
                when {
                    state.loading -> Box(
                        Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center,
                    ) { CircularProgressIndicator() }

                    state.rfq == null -> EmptyStateView(
                        icon = Icons.Outlined.RequestQuote,
                        title = "RFQ not found",
                        subtitle = "The RFQ may have been removed.",
                    )

                    else -> RfqDetailContent(
                        rfq = state.rfq!!,
                        bids = state.bids,
                        acceptingBidId = state.acceptingBidId,
                        openingChatForBidId = state.openingChatForBidId,
                        onAcceptBid = viewModel::onAcceptBid,
                        onMessageBid = viewModel::onMessageSupplier,
                    )
                }
            }
        }
    }
}

@Composable
private fun RfqDetailContent(
    rfq: Rfq,
    bids: List<RfqBid>,
    acceptingBidId: String?,
    openingChatForBidId: String?,
    onAcceptBid: (RfqBid) -> Unit,
    onMessageBid: (RfqBid) -> Unit,
) {
    // Identify the leading bid (lowest total price) so the BidCard can flag it
    // as the top match.
    val topMatchId = bids
        .filter { it.totalPriceRupees > 0 }
        .minByOrNull { it.totalPriceRupees }
        ?.id

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = Spacing.lg, vertical = Spacing.md),
        verticalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        item { RfqSummaryCard(rfq) }

        item { SectionHeader(title = "Bids received (${bids.size})") }

        if (bids.isEmpty()) {
            item {
                EmptyStateView(
                    icon = Icons.Outlined.RequestQuote,
                    title = "No bids yet",
                    subtitle = "Suppliers will post quotes here once they review this RFQ.",
                )
            }
        } else {
            items(items = bids, key = { it.id }) { bid ->
                SupplierBidSection(
                    bid = bid,
                    isTopMatch = bid.id == topMatchId,
                    rfqIsOpen = rfq.isOpen,
                    accepting = acceptingBidId == bid.id,
                    acceptEnabled = acceptingBidId == null,
                    openingChat = openingChatForBidId == bid.id,
                    onAccept = { onAcceptBid(bid) },
                    onMessage = { onMessageBid(bid) },
                )
            }
        }
    }
}

@Composable
private fun RfqSummaryCard(rfq: Rfq) {
    val shape = MaterialTheme.shapes.large
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(Surface0)
            .border(1.dp, Surface200, shape)
            .padding(Spacing.lg),
        verticalArrangement = Arrangement.spacedBy(Spacing.xs),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.Top,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = rfq.title,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.SemiBold,
                    color = Ink900,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                rfq.rfqNumber?.takeIf { it.isNotBlank() }?.let {
                    Text(
                        text = "#$it",
                        style = MaterialTheme.typography.labelMedium,
                        color = Ink500,
                    )
                }
            }
            StatusChip(
                label = rfq.status.replaceFirstChar { it.uppercase() },
                tone = if (rfq.isOpen) StatusTone.Info else StatusTone.Neutral,
            )
        }

        rfq.equipmentCategory?.takeIf { it.isNotBlank() }?.let {
            Text(
                text = it,
                style = MaterialTheme.typography.bodyMedium,
                color = Ink700,
            )
        }

        // Chip strip: budget · qty · deadline
        Row(
            horizontalArrangement = Arrangement.spacedBy(Spacing.xs),
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = Spacing.xs),
        ) {
            formatBudgetRange(rfq.budgetMinRupees, rfq.budgetMaxRupees)?.let { budget ->
                StatusChip(label = budget, tone = StatusTone.Success)
            }
            StatusChip(label = "Qty ${rfq.quantity}", tone = StatusTone.Neutral)
            rfq.deliveryDeadlineIso?.takeIf { it.isNotBlank() }?.let {
                StatusChip(label = "By $it", tone = StatusTone.Warn)
            }
        }

        rfq.description?.takeIf { it.isNotBlank() }?.let {
            Text(
                text = it,
                style = MaterialTheme.typography.bodyMedium,
                color = Ink700,
                modifier = Modifier.padding(top = Spacing.xs),
            )
        }

        rfq.deliveryLocation?.takeIf { it.isNotBlank() }?.let {
            Text(
                text = "Ship to: $it",
                style = MaterialTheme.typography.labelMedium,
                color = Ink500,
            )
        }
        rfq.createdAtInstant?.let {
            Text(
                text = "Posted ${relativeLabel(it)} ago",
                style = MaterialTheme.typography.labelMedium,
                color = Ink500,
            )
        }
    }
}

@Composable
private fun SupplierBidSection(
    bid: RfqBid,
    isTopMatch: Boolean,
    rfqIsOpen: Boolean,
    accepting: Boolean,
    acceptEnabled: Boolean,
    openingChat: Boolean,
    onAccept: () -> Unit,
    onMessage: () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
        // BidCard primitive — supplier maps to the "engineer" param. RfqBid has
        // no supplier name / rating yet, so we synthesize a stable id-based
        // label and zero rating; isVerified reflects accepted/awarded status.
        BidCard(
            engineerName = supplierLabel(bid.manufacturerId),
            rating = 0f,
            ratingCount = 0,
            amountRupees = bid.totalPriceRupees,
            etaHours = null,
            isVerified = bid.status.equals("accepted", ignoreCase = true) ||
                bid.status.equals("awarded", ignoreCase = true),
            isTopMatch = isTopMatch,
        )

        BidMetaRow(bid = bid)

        if (rfqIsOpen && bid.status.equals("submitted", ignoreCase = true)) {
            PrimaryButton(
                label = "Accept bid",
                loading = accepting,
                enabled = acceptEnabled && !accepting,
                onClick = onAccept,
            )
        }
        TonalButton(
            label = if (openingChat) "Opening…" else "Message supplier",
            enabled = !openingChat,
            onClick = onMessage,
        )
    }
}

@Composable
private fun BidMetaRow(bid: RfqBid) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.xxs)) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = Spacing.xs),
            horizontalArrangement = Arrangement.spacedBy(Spacing.xs),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            StatusChip(
                label = "${formatRupees(bid.unitPriceRupees)} / unit",
                tone = StatusTone.Neutral,
            )
            bid.deliveryTimelineDays?.let {
                StatusChip(label = "${it}d delivery", tone = StatusTone.Info)
            }
            bid.warrantyMonths?.let {
                StatusChip(label = "${it}mo warranty", tone = StatusTone.Success)
            }
        }
        val extras = buildList {
            if (bid.includesInstallation) add("Installation")
            if (bid.includesTraining) add("Training")
        }
        if (extras.isNotEmpty()) {
            Text(
                text = "Includes: ${extras.joinToString(", ")}",
                style = MaterialTheme.typography.labelMedium,
                color = Ink500,
                modifier = Modifier.padding(horizontal = Spacing.xs),
            )
        }
        bid.notes?.takeIf { it.isNotBlank() }?.let {
            Text(
                text = it,
                style = MaterialTheme.typography.bodySmall,
                color = Ink700,
                modifier = Modifier.padding(horizontal = Spacing.xs),
            )
        }
        bid.createdAtIso?.let { iso ->
            runCatching { Instant.parse(iso) }.getOrNull()?.let {
                Text(
                    text = "Received ${relativeLabel(it)} ago",
                    style = MaterialTheme.typography.labelMedium,
                    color = Ink500,
                    modifier = Modifier.padding(horizontal = Spacing.xs),
                )
            }
        }
    }
}

private fun supplierLabel(manufacturerId: String): String =
    "Supplier ${manufacturerId.take(6).uppercase()}"

private fun formatBudgetRange(min: Double?, max: Double?): String? = when {
    min != null && max != null && max > min -> "${formatRupees(min)} – ${formatRupees(max)}"
    max != null -> "Up to ${formatRupees(max)}"
    min != null -> "From ${formatRupees(min)}"
    else -> null
}
