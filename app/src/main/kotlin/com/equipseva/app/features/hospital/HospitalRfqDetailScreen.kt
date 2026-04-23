package com.equipseva.app.features.hospital

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
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.data.rfq.Rfq
import com.equipseva.app.core.data.rfq.RfqBid
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.core.util.relativeLabel
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.SectionHeader
import com.equipseva.app.designsystem.components.StatusChip
import com.equipseva.app.designsystem.components.StatusTone
import com.equipseva.app.designsystem.theme.Spacing
import java.time.Instant

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HospitalRfqDetailScreen(
    onBack: () -> Unit,
    viewModel: HospitalRfqDetailViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Scaffold(
        topBar = { ESBackTopBar(title = "RFQ details", onBack = onBack) },
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

                    else -> RfqDetailContent(rfq = state.rfq!!, bids = state.bids)
                }
            }
        }
    }
}

@Composable
private fun RfqDetailContent(rfq: Rfq, bids: List<RfqBid>) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = Spacing.lg, vertical = Spacing.md),
        verticalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        item { RfqSummaryCard(rfq) }

        item { SectionHeader(title = "Bids (${bids.size})") }

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
                BidCard(bid = bid)
            }
        }
    }
}

@Composable
private fun RfqSummaryCard(rfq: Rfq) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
    ) {
        Column(
            modifier = Modifier.padding(Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.xs),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = rfq.title,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.weight(1f),
                )
                StatusChip(
                    label = rfq.status.replaceFirstChar { it.uppercase() },
                    tone = if (rfq.isOpen) StatusTone.Info else StatusTone.Neutral,
                )
            }
            rfq.rfqNumber?.let {
                Text(
                    text = "#$it",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            rfq.equipmentCategory?.takeIf { it.isNotBlank() }?.let {
                Text(text = it, style = MaterialTheme.typography.bodyMedium)
            }
            rfq.description?.takeIf { it.isNotBlank() }?.let {
                Text(
                    text = it,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Text(
                text = "Quantity: ${rfq.quantity}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            val budget = formatBudgetRange(rfq.budgetMinRupees, rfq.budgetMaxRupees)
            if (budget != null) {
                Text(
                    text = "Budget: $budget",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            rfq.deliveryLocation?.takeIf { it.isNotBlank() }?.let {
                Text(
                    text = "Ship to: $it",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            rfq.deliveryDeadlineIso?.takeIf { it.isNotBlank() }?.let {
                Text(
                    text = "Deliver by: $it",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            rfq.createdAtInstant?.let {
                Text(
                    text = "Posted ${relativeLabel(it)} ago",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun BidCard(bid: RfqBid) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
    ) {
        Column(
            modifier = Modifier.padding(Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.xxs),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = formatRupees(bid.totalPriceRupees),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                )
                StatusChip(
                    label = bid.status.replaceFirstChar { it.uppercase() },
                    tone = when (bid.status.lowercase()) {
                        "accepted", "awarded" -> StatusTone.Success
                        "rejected" -> StatusTone.Danger
                        else -> StatusTone.Info
                    },
                )
            }
            Text(
                text = "${formatRupees(bid.unitPriceRupees)} / unit",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            bid.deliveryTimelineDays?.let {
                Text(
                    text = "Delivery in $it day(s)",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            bid.warrantyMonths?.let {
                Text(
                    text = "Warranty: $it month(s)",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            val extras = buildList {
                if (bid.includesInstallation) add("Installation")
                if (bid.includesTraining) add("Training")
            }
            if (extras.isNotEmpty()) {
                Text(
                    text = "Includes: ${extras.joinToString(", ")}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            bid.notes?.takeIf { it.isNotBlank() }?.let {
                Text(
                    text = it,
                    style = MaterialTheme.typography.bodySmall,
                )
            }
            bid.createdAtIso?.let { iso ->
                runCatching { Instant.parse(iso) }.getOrNull()?.let {
                    Text(
                        text = "Received ${relativeLabel(it)} ago",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}

private fun formatBudgetRange(min: Double?, max: Double?): String? = when {
    min != null && max != null && max > min -> "${formatRupees(min)} – ${formatRupees(max)}"
    max != null -> "up to ${formatRupees(max)}"
    min != null -> "from ${formatRupees(min)}"
    else -> null
}
