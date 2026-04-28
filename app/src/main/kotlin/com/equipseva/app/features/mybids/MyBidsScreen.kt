package com.equipseva.app.features.mybids

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CloudSync
import androidx.compose.material.icons.outlined.Gavel
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.data.repair.RepairBidStatus
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.core.util.relativeLabel
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.EsChip
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.ListSkeleton
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk400
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MyBidsScreen(
    onBack: () -> Unit,
    onJobClick: (String) -> Unit,
    viewModel: MyBidsViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val activeFilter = state.statusFilter ?: RepairBidStatus.Pending
    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "My bids", onBack = onBack)
            ErrorBanner(message = state.errorMessage)
            QueuedBidPill(count = state.queuedBidCount)

            // 3-tab chip strip — design uses 3 explicit tabs (Pending / Accepted / Rejected).
            val groups = remember(state.rows) {
                listOf(
                    RepairBidStatus.Pending,
                    RepairBidStatus.Accepted,
                    RepairBidStatus.Rejected,
                ).map { status -> status to state.rows.count { it.bid.status == status } }
            }
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                groups.forEach { (status, count) ->
                    EsChip(
                        text = "${status.displayName} ($count)",
                        active = activeFilter == status,
                        onClick = { viewModel.onStatusFilterChange(status) },
                    )
                }
            }

            PullToRefreshBox(
                isRefreshing = state.refreshing,
                onRefresh = viewModel::onRefresh,
                modifier = Modifier.fillMaxSize(),
            ) {
                val visibleRows = state.rows.filter { it.bid.status == activeFilter }
                when {
                    state.loading && state.rows.isEmpty() -> ListSkeleton(rows = 8)
                    visibleRows.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.Gavel,
                        title = "No ${activeFilter.displayName.lowercase()} bids",
                        subtitle = if (activeFilter == RepairBidStatus.Pending)
                            "Bids you place on repair jobs will appear here."
                        else "Switch tabs to see other bid states.",
                    )
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp),
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
private fun BidRowCard(
    row: MyBidsViewModel.MyBidRow,
    onClick: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.Top,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                text = row.job?.title ?: "Repair job",
                style = EsType.Body.copy(fontWeight = FontWeight.SemiBold),
                color = SevaInk900,
                modifier = Modifier.weight(1f),
            )
            val pillKind = when (row.bid.status) {
                RepairBidStatus.Accepted -> PillKind.Success
                RepairBidStatus.Rejected -> PillKind.Danger
                RepairBidStatus.Withdrawn -> PillKind.Neutral
                else -> PillKind.Info
            }
            Pill(text = row.bid.status.displayName, kind = pillKind)
        }
        row.job?.equipmentLabel?.let {
            Text(
                text = it,
                style = EsType.Caption,
                color = SevaInk500,
            )
        }
        Box(modifier = Modifier.fillMaxWidth().height(1.dp).background(BorderDefault))
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = formatRupees(row.bid.amountRupees),
                style = EsType.H5,
                color = SevaGreen700,
            )
            row.bid.createdAtInstant?.let { placed ->
                Text(
                    text = "Placed ${relativeLabel(placed)} ago",
                    style = EsType.Caption,
                    color = SevaInk400,
                )
            }
        }
    }
}

@Composable
private fun QueuedBidPill(count: Int) {
    if (count <= 0) return
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 4.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(SevaGreen50)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(
            imageVector = Icons.Outlined.CloudSync,
            contentDescription = null,
            tint = SevaGreen700,
            modifier = Modifier.size(16.dp),
        )
        Text(
            text = if (count == 1) "1 bid queued — will submit when back online"
            else "$count bids queued — will submit when back online",
            style = EsType.Caption,
            color = SevaInk900,
        )
    }
}
