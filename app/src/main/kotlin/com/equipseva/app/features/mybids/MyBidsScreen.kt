package com.equipseva.app.features.mybids

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CloudSync
import androidx.compose.material.icons.outlined.Gavel
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.data.repair.RepairBidStatus
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.core.util.relativeLabel
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.GradientTile
import com.equipseva.app.designsystem.components.StatusChip
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreen50
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface100
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.designsystem.theme.Surface50
import com.equipseva.app.features.repair.components.iconForEquipment
import com.equipseva.app.features.repair.components.toTone

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MyBidsScreen(
    onBack: () -> Unit,
    onJobClick: (String) -> Unit,
    viewModel: MyBidsViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    val pendingCount = state.rows.count { it.bid.status == RepairBidStatus.Pending }
    val acceptedCount = state.rows.count { it.bid.status == RepairBidStatus.Accepted }
    val rejectedCount = state.rows.count { it.bid.status == RepairBidStatus.Rejected }

    Scaffold(
        topBar = { ESBackTopBar(title = "My bids", onBack = onBack) },
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
            QueuedBidPill(count = state.queuedBidCount)
            if (state.rows.isNotEmpty()) {
                BidStatusTabs(
                    selected = state.statusFilter,
                    pendingCount = pendingCount,
                    acceptedCount = acceptedCount,
                    rejectedCount = rejectedCount,
                    onSelect = viewModel::onStatusFilterChange,
                )
            }
            PullToRefreshBox(
                isRefreshing = state.refreshing,
                onRefresh = viewModel::onRefresh,
                modifier = Modifier.fillMaxSize(),
            ) {
                val visibleRows = state.visibleRows
                when {
                    state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                    state.rows.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.Gavel,
                        title = "No bids yet",
                        subtitle = "Bids you place on repair jobs will appear here.",
                    )
                    visibleRows.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.Gavel,
                        title = "No bids match this filter",
                        subtitle = "Try switching the status filter above.",
                    )
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(horizontal = Spacing.lg, vertical = Spacing.md),
                        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
                    ) {
                        items(items = visibleRows, key = { it.bid.id }) { row ->
                            BidRowCard(
                                row = row,
                                onClick = { onJobClick(row.bid.repairJobId) },
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun BidStatusTabs(
    selected: RepairBidStatus?,
    pendingCount: Int,
    acceptedCount: Int,
    rejectedCount: Int,
    onSelect: (RepairBidStatus?) -> Unit,
) {
    val tabs = listOf(
        Triple(null, "All", pendingCount + acceptedCount + rejectedCount),
        Triple(RepairBidStatus.Pending, "Pending", pendingCount),
        Triple(RepairBidStatus.Accepted, "Accepted", acceptedCount),
        Triple(RepairBidStatus.Rejected, "Rejected", rejectedCount),
    )
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surface)
            .padding(horizontal = Spacing.sm),
        horizontalArrangement = Arrangement.spacedBy(Spacing.xs),
    ) {
        tabs.forEach { (status, label, count) ->
            BidTabItem(
                label = label,
                count = count,
                selected = selected == status,
                onClick = { onSelect(status) },
            )
        }
    }
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(1.dp)
            .background(Surface200),
    )
}

@Composable
private fun BidTabItem(
    label: String,
    count: Int,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val labelColor = if (selected) BrandGreenDark else Ink500
    val underlineColor = if (selected) BrandGreen else androidx.compose.ui.graphics.Color.Transparent
    val pillBg = if (selected) BrandGreen50 else Surface100
    Column(
        modifier = Modifier
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Text(
                text = label,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = labelColor,
            )
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(percent = 50))
                    .background(pillBg)
                    .padding(horizontal = 6.dp, vertical = 1.dp),
            ) {
                Text(
                    text = count.toString(),
                    fontSize = 11.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = labelColor,
                )
            }
        }
        Box(
            modifier = Modifier
                .padding(top = 8.dp)
                .height(2.dp)
                .background(underlineColor)
                .fillMaxWidth(),
        )
    }
}

@Composable
private fun BidRowCard(
    row: MyBidsViewModel.MyBidRow,
    onClick: () -> Unit,
) {
    val shape = MaterialTheme.shapes.medium
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surface, shape)
            .border(1.dp, Surface200, shape)
            .clickable(onClick = onClick)
            .padding(Spacing.md),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(Spacing.md),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            val (hue, icon) = pickHueIcon(row.job)
            GradientTile(icon = icon, hue = hue, size = 52.dp)
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = row.job?.equipmentLabel ?: row.job?.title ?: "Repair job",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    color = Ink900,
                )
                row.bid.createdAtInstant?.let { placed ->
                    Text(
                        text = "Bid placed ${relativeLabel(placed)} ago",
                        fontSize = 12.sp,
                        color = Ink500,
                        modifier = Modifier.padding(top = 2.dp),
                    )
                }
                row.bid.etaHours?.let { eta ->
                    Text(
                        text = "ETA ${eta}h",
                        fontSize = 12.sp,
                        color = Ink500,
                        modifier = Modifier.padding(top = 2.dp),
                    )
                }
            }
            Column(
                horizontalAlignment = Alignment.End,
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Text(
                    text = formatRupees(row.bid.amountRupees),
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = BrandGreenDark,
                )
                StatusChip(
                    label = row.bid.status.displayName,
                    tone = row.bid.status.toTone(),
                )
            }
        }
    }
}

@Composable
private fun pickHueIcon(job: RepairJob?): Pair<Int, androidx.compose.ui.graphics.vector.ImageVector> {
    return if (job != null) iconForEquipment(job)
    else 150 to Icons.Outlined.Gavel
}

@Composable
private fun QueuedBidPill(count: Int) {
    if (count <= 0) return
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg, vertical = Spacing.xs)
            .clip(MaterialTheme.shapes.small)
            .background(BrandGreen50)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(
            imageVector = Icons.Outlined.CloudSync,
            contentDescription = null,
            tint = BrandGreen,
            modifier = Modifier.size(16.dp),
        )
        Text(
            text = if (count == 1) "1 bid queued — will submit when back online"
            else "$count bids queued — will submit when back online",
            style = MaterialTheme.typography.bodySmall,
            color = Ink900,
        )
    }
}
