package com.equipseva.app.features.manufacturer

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
import androidx.compose.material.icons.outlined.Insights
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EquipmentArt
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.GradientTile
import com.equipseva.app.designsystem.components.StatusBanner
import com.equipseva.app.designsystem.components.StatusBannerTone
import com.equipseva.app.designsystem.components.StatusChip
import com.equipseva.app.designsystem.components.StatusTone
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.designsystem.theme.Surface50

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LeadPipelineScreen(
    onBack: () -> Unit,
    viewModel: LeadPipelineViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Scaffold(
        topBar = { ESBackTopBar(title = "Lead pipeline", onBack = onBack) },
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
            if (state.noManufacturerWarning) {
                StatusBanner(
                    title = "Manufacturer not linked",
                    message = "Register your organization as a manufacturer to bid on RFQs.",
                    tone = StatusBannerTone.Warn,
                    leadingIcon = Icons.Outlined.Insights,
                    modifier = Modifier.padding(horizontal = Spacing.lg, vertical = Spacing.sm),
                )
            }
            PullToRefreshBox(
                isRefreshing = state.refreshing,
                onRefresh = viewModel::onRefresh,
                modifier = Modifier.fillMaxSize(),
            ) {
                when {
                    state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                    state.rows.isEmpty() && !state.noManufacturerWarning -> EmptyStateView(
                        icon = Icons.Outlined.Insights,
                        title = "No bids placed yet",
                        subtitle = "Bids you submit on RFQs will show up here.",
                    )
                    state.rows.isEmpty() -> Box(Modifier)
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(horizontal = Spacing.lg, vertical = Spacing.md),
                        verticalArrangement = Arrangement.spacedBy(Spacing.md),
                    ) {
                        items(items = state.rows, key = { it.bid.id }) { row ->
                            LeadCard(row = row)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun LeadCard(row: LeadPipelineViewModel.LeadRow) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(MaterialTheme.shapes.large)
            .background(Surface0)
            .border(1.dp, Surface200, MaterialTheme.shapes.large)
            .padding(Spacing.lg),
        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(Spacing.md),
            verticalAlignment = Alignment.Top,
        ) {
            GradientTile(art = EquipmentArt.PrecisionManufacturing, hue = 150, size = 48.dp)
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                Text(
                    text = row.rfq?.title ?: "RFQ",
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Ink900,
                )
                row.rfq?.rfqNumber?.takeIf { it.isNotBlank() }?.let {
                    Text(
                        text = "RFQ #$it",
                        style = MaterialTheme.typography.labelMedium,
                        color = Ink500,
                    )
                }
            }
            StatusChip(
                label = row.bid.status.replaceFirstChar { it.uppercase() },
                tone = row.bid.status.toTone(),
            )
        }
        Text(
            text = formatRupees(row.bid.totalPriceRupees),
            style = MaterialTheme.typography.titleMedium,
            color = BrandGreenDark,
            fontWeight = FontWeight.SemiBold,
        )
        val meta = buildList {
            row.bid.deliveryTimelineDays?.let { add("Delivery ${it}d") }
            row.bid.warrantyMonths?.let { add("Warranty ${it}m") }
            if (row.bid.includesInstallation) add("Install incl.")
            if (row.bid.includesTraining) add("Training incl.")
        }.joinToString(" · ")
        if (meta.isNotBlank()) {
            Text(
                text = meta,
                style = MaterialTheme.typography.bodySmall,
                color = Ink500,
            )
        }
        row.bid.notes?.takeIf { it.isNotBlank() }?.let {
            Text(
                text = it,
                style = MaterialTheme.typography.bodySmall,
                color = Ink500,
                maxLines = 2,
            )
        }
    }
}

private fun String.toTone(): StatusTone = when (lowercase()) {
    "submitted", "pending" -> StatusTone.Info
    "shortlisted" -> StatusTone.Warn
    "awarded", "accepted" -> StatusTone.Success
    "rejected", "withdrawn" -> StatusTone.Danger
    else -> StatusTone.Neutral
}
