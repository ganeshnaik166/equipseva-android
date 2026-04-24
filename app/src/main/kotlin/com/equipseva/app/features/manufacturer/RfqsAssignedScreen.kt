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
import androidx.compose.material.icons.outlined.Business
import androidx.compose.material.icons.outlined.RequestQuote
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
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.data.rfq.Rfq
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EquipmentArt
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.GradientTile
import com.equipseva.app.designsystem.components.SectionHeader
import com.equipseva.app.designsystem.components.StatusBanner
import com.equipseva.app.designsystem.components.StatusBannerTone
import com.equipseva.app.designsystem.components.StatusChip
import com.equipseva.app.designsystem.components.StatusTone
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.designsystem.theme.Surface50
import java.time.Duration
import java.time.Instant

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RfqsAssignedScreen(
    onBack: () -> Unit,
    viewModel: RfqsAssignedViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Scaffold(
        topBar = { ESBackTopBar(title = "Matched RFQs", onBack = onBack) },
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
            if (state.noOrgWarning) {
                StatusBanner(
                    title = "Manufacturer not linked",
                    message = "Link your account to a manufacturer organization to receive RFQs.",
                    tone = StatusBannerTone.Warn,
                    leadingIcon = Icons.Outlined.Business,
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
                    state.targeted.isEmpty() && state.other.isEmpty() && !state.noOrgWarning -> EmptyStateView(
                        icon = Icons.Outlined.RequestQuote,
                        title = "No open RFQs",
                        subtitle = "New equipment inquiries will appear here.",
                    )
                    state.targeted.isEmpty() && state.other.isEmpty() -> Box(Modifier)
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(bottom = Spacing.lg),
                        verticalArrangement = Arrangement.spacedBy(Spacing.md),
                    ) {
                        if (state.targeted.isNotEmpty()) {
                            item("targeted_header") { SectionHeader(title = "Matches your categories") }
                            items(items = state.targeted, key = { "t-${it.id}" }) { rfq ->
                                Box(modifier = Modifier.padding(horizontal = Spacing.lg)) {
                                    ManufacturerRfqCard(rfq = rfq, isMatched = true)
                                }
                            }
                        }
                        if (state.other.isNotEmpty()) {
                            item("other_header") { SectionHeader(title = "Other open RFQs") }
                            items(items = state.other, key = { "o-${it.id}" }) { rfq ->
                                Box(modifier = Modifier.padding(horizontal = Spacing.lg)) {
                                    ManufacturerRfqCard(rfq = rfq, isMatched = false)
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
private fun ManufacturerRfqCard(rfq: Rfq, isMatched: Boolean) {
    // Hue 150 (green) for matched RFQs, hue 200 (blue) for "other".
    val hue = if (isMatched) 150 else 200
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
            GradientTile(art = EquipmentArt.MedicalServices, hue = hue, size = 48.dp)
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                Text(
                    text = rfq.title,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Ink900,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                rfq.rfqNumber?.takeIf { it.isNotBlank() }?.let {
                    Text(
                        text = "RFQ #$it",
                        style = MaterialTheme.typography.labelMedium,
                        color = Ink500,
                    )
                }
            }
        }

        // Chip row: budget + deadline urgency.
        val budgetChip = formatBudgetChip(rfq.budgetMinRupees, rfq.budgetMaxRupees)
        val deadlineChip = deadlineChip(rfq.deliveryDeadlineInstant)
        if (budgetChip != null || deadlineChip != null) {
            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.xs)) {
                if (budgetChip != null) {
                    StatusChip(label = budgetChip, tone = StatusTone.Info)
                }
                if (deadlineChip != null) {
                    StatusChip(label = deadlineChip.label, tone = deadlineChip.tone)
                }
            }
        }

        rfq.equipmentCategory?.takeIf { it.isNotBlank() }?.let {
            Text(
                text = it,
                style = MaterialTheme.typography.bodyMedium,
                color = Ink900,
            )
        }
        rfq.description?.takeIf { it.isNotBlank() }?.let {
            Text(
                text = it,
                style = MaterialTheme.typography.bodySmall,
                color = Ink500,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
        }
        rfq.deliveryLocation?.takeIf { it.isNotBlank() }?.let {
            Text(
                text = "Ship to $it",
                style = MaterialTheme.typography.bodySmall,
                color = Ink500,
            )
        }
        Text(
            text = "Qty ${rfq.quantity} · ${rfq.bidsCount} bid(s)",
            style = MaterialTheme.typography.bodySmall,
            color = Ink500,
        )
    }
}

private fun formatBudgetChip(min: Double?, max: Double?): String? {
    if (min == null && max == null) return null
    return when {
        min != null && max != null && min != max -> "₹${formatRupees(min)} – ₹${formatRupees(max)}"
        max != null -> "Up to ₹${formatRupees(max)}"
        min != null -> "From ₹${formatRupees(min)}"
        else -> null
    }
}

private data class DeadlineChip(val label: String, val tone: StatusTone)

private fun deadlineChip(deadline: Instant?): DeadlineChip? {
    if (deadline == null) return null
    val now = Instant.now()
    if (deadline.isBefore(now)) return DeadlineChip("Past due", StatusTone.Danger)
    val hoursLeft = Duration.between(now, deadline).toHours()
    val label = when {
        hoursLeft < 24 -> "Due in ${hoursLeft}h"
        hoursLeft < 24 * 7 -> "Due in ${hoursLeft / 24}d"
        else -> "Due ${deadline.toString().take(10)}"
    }
    val tone = if (hoursLeft < 48) StatusTone.Warn else StatusTone.Neutral
    return DeadlineChip(label, tone)
}
