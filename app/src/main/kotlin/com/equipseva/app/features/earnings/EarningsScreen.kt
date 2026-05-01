package com.equipseva.app.features.earnings

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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CurrencyRupee
import androidx.compose.material.icons.outlined.Payments
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.core.util.relativeLabel
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.EsSection
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.SecureScreen
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGlowRaw
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaGreen900
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.designsystem.theme.SevaWarning50
import com.equipseva.app.designsystem.theme.SevaWarning500

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EarningsScreen(
    onBack: (() -> Unit)? = null,
    onJobClick: (String) -> Unit,
    onBankDetails: () -> Unit = {},
    viewModel: EarningsViewModel = hiltViewModel(),
) {
    SecureScreen()
    val state by viewModel.state.collectAsStateWithLifecycle()

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "Earnings", onBack = onBack)
            ErrorBanner(message = state.errorMessage)
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
                        contentPadding = PaddingValues(bottom = 24.dp),
                    ) {
                        item("hero") {
                            Box(
                                modifier = Modifier.padding(
                                    start = 16.dp,
                                    end = 16.dp,
                                    top = 8.dp,
                                    bottom = 16.dp,
                                ),
                            ) {
                                EarningsHero(
                                    paidTotal = state.paidTotal,
                                    pendingTotal = state.pendingTotal,
                                )
                            }
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
                            item("history") {
                                EsSection(
                                    title = "Recent payouts",
                                    action = "Bank details",
                                    onAction = onBankDetails,
                                ) {
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
}

@Composable
private fun EarningsHero(paidTotal: Double, pendingTotal: Double) {
    val total = paidTotal + pendingTotal
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Brush.linearGradient(listOf(SevaGreen700, SevaGreen900)))
            .padding(18.dp),
    ) {
        Text(
            text = "This month",
            fontSize = 12.sp,
            color = Color.White.copy(alpha = 0.7f),
        )
        Spacer(Modifier.height(4.dp))
        Text(
            text = formatRupees(total),
            fontSize = 32.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = (-0.64).sp,
            color = Color.White,
        )
        Spacer(Modifier.height(14.dp))
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(1.dp)
                .background(Color.White.copy(alpha = 0.15f)),
        )
        Spacer(Modifier.height(14.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            HeroStat(label = "Paid", value = formatRupees(paidTotal), tint = Color.White)
            HeroStat(label = "Pending", value = formatRupees(pendingTotal), tint = SevaGlowRaw)
        }
    }
}

@Composable
private fun HeroStat(label: String, value: String, tint: Color) {
    Column {
        Text(label, fontSize = 11.sp, color = Color.White.copy(alpha = 0.65f))
        Spacer(Modifier.height(2.dp))
        Text(value, fontSize = 16.sp, fontWeight = FontWeight.Bold, color = tint)
    }
}

@Composable
private fun TransactionsList(
    rows: List<EarningsViewModel.EarningRow>,
    onJobClick: (String) -> Unit,
) {
    Column(
        modifier = Modifier
            .padding(horizontal = 16.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp)),
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
                        .background(BorderDefault),
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
    val tileBg = if (paid) SevaGreen50 else SevaWarning50
    val tileFg = if (paid) SevaGreen700 else SevaWarning500
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            modifier = Modifier
                .size(32.dp)
                .clip(RoundedCornerShape(8.dp))
                .background(tileBg),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                Icons.Filled.CurrencyRupee,
                contentDescription = null,
                tint = tileFg,
                modifier = Modifier.size(14.dp),
            )
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = row.job?.title ?: "Repair job",
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = SevaInk900,
                maxLines = 1,
            )
            val timestamp = if (paid) row.job?.completedAtInstant else row.bid.createdAtInstant
            val timeLine = timestamp?.let { "${if (paid) "Paid" else "Quoted"} ${relativeLabel(it)} ago" }
                ?: row.job?.status?.displayName ?: ""
            Text(
                text = timeLine,
                fontSize = 11.sp,
                color = SevaInk500,
                maxLines = 1,
            )
        }
        Column(horizontalAlignment = Alignment.End) {
            Text(
                text = formatRupees(row.bid.amountRupees),
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                color = SevaInk900,
            )
            Text(
                text = if (paid) "paid" else "pending",
                fontSize = 10.sp,
                fontWeight = FontWeight.SemiBold,
                color = if (paid) SevaGreen700 else SevaWarning500,
            )
        }
    }
}
