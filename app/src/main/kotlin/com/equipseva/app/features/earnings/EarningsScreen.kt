package com.equipseva.app.features.earnings

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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.outlined.Payments
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
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.core.util.relativeLabel
import com.equipseva.app.designsystem.components.EarningsHeroCard
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.SecureScreen
import com.equipseva.app.designsystem.components.SectionHeader
import com.equipseva.app.designsystem.components.StatusChip
import com.equipseva.app.designsystem.components.StatusTone
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Success
import com.equipseva.app.designsystem.theme.SuccessBg
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface50
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.designsystem.theme.Warning
import com.equipseva.app.designsystem.theme.WarningBg

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EarningsScreen(
    onBack: () -> Unit,
    onJobClick: (String) -> Unit,
    viewModel: EarningsViewModel = hiltViewModel(),
) {
    SecureScreen()
    val state by viewModel.state.collectAsStateWithLifecycle()

    Scaffold(
        topBar = { ESBackTopBar(title = "Earnings", onBack = onBack) },
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
                    state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(bottom = Spacing.xl),
                        verticalArrangement = Arrangement.spacedBy(0.dp),
                    ) {
                        item("hero") {
                            EarningsHeroCard(
                                totalRupees = state.paidTotal + state.pendingTotal,
                                paidRupees = state.paidTotal,
                                pendingRupees = state.pendingTotal,
                                onWithdraw = {},
                                modifier = Modifier.padding(
                                    start = Spacing.lg,
                                    end = Spacing.lg,
                                    top = Spacing.lg,
                                    bottom = Spacing.sm,
                                ),
                            )
                        }
                        if (state.rows.isEmpty()) {
                            item("empty") {
                                EmptyStateView(
                                    icon = Icons.Outlined.Payments,
                                    title = "No earnings yet",
                                    subtitle = "Complete accepted jobs to start earning.",
                                )
                            }
                        } else {
                            item("history_header") {
                                SectionHeader(title = "Transactions")
                            }
                            item("history_list") {
                                TransactionsList(
                                    rows = state.rows,
                                    onJobClick = onJobClick,
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun TransactionsList(
    rows: List<EarningsViewModel.EarningRow>,
    onJobClick: (String) -> Unit,
) {
    Column(
        modifier = Modifier
            .padding(horizontal = Spacing.lg)
            .fillMaxWidth()
            .clip(MaterialTheme.shapes.large)
            .background(Surface0)
            .border(1.dp, Surface200, MaterialTheme.shapes.large),
    ) {
        rows.forEachIndexed { index, row ->
            TransactionRow(
                row = row,
                onClick = { onJobClick(row.bid.repairJobId) },
            )
            if (index < rows.size - 1) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(1.dp)
                        .background(Surface200),
                )
            }
        }
    }
}

@Composable
private fun TransactionRow(
    row: EarningsViewModel.EarningRow,
    onClick: () -> Unit,
) {
    val paid = row.job?.status == RepairJobStatus.Completed
    val iconBg = if (paid) SuccessBg else WarningBg
    val iconTint = if (paid) Success else Warning
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            modifier = Modifier
                .size(36.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(iconBg),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = Icons.Filled.ArrowDownward,
                contentDescription = null,
                tint = iconTint,
                modifier = Modifier.size(18.dp),
            )
        }
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                text = row.job?.title ?: "Repair job",
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = Ink900,
                maxLines = 1,
            )
            val jobNumber = row.job?.jobNumber?.takeIf { it.isNotBlank() }
            val status = row.job?.status?.displayName ?: "In progress"
            val subtitle = jobNumber?.let { "#$it · $status" } ?: status
            Text(
                text = subtitle,
                fontSize = 12.sp,
                color = Ink500,
                maxLines = 1,
            )
            val timestamp = if (paid) row.job?.completedAtInstant else row.bid.createdAtInstant
            timestamp?.let {
                val prefix = if (paid) "Paid" else "Quoted"
                Text(
                    text = "$prefix ${relativeLabel(it)} ago",
                    fontSize = 11.sp,
                    color = Ink500,
                    maxLines = 1,
                )
            }
        }
        Column(
            horizontalAlignment = Alignment.End,
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Text(
                text = "+${formatRupees(row.bid.amountRupees)}",
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                color = Ink900,
            )
            val tone: StatusTone = when (row.job?.status) {
                RepairJobStatus.Completed -> StatusTone.Success
                RepairJobStatus.Cancelled, RepairJobStatus.Disputed -> StatusTone.Danger
                else -> StatusTone.Warn
            }
            val label = if (paid) "paid" else "pending"
            StatusChip(label = label, tone = tone)
        }
    }
}
