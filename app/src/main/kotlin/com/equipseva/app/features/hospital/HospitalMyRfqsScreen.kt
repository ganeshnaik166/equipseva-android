package com.equipseva.app.features.hospital

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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.RequestQuote
import androidx.compose.material.icons.outlined.WarningAmber
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
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.data.rfq.Rfq
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.core.util.relativeLabel
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.StatusBanner
import com.equipseva.app.designsystem.components.StatusBannerTone
import com.equipseva.app.designsystem.components.StatusChip
import com.equipseva.app.designsystem.components.StatusTone
import com.equipseva.app.designsystem.components.rememberTapInteractionSource
import com.equipseva.app.designsystem.components.tapScale
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.designsystem.theme.Surface50

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HospitalMyRfqsScreen(
    onBack: () -> Unit,
    onRfqClick: (String) -> Unit = {},
    viewModel: HospitalMyRfqsViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Scaffold(
        topBar = { ESBackTopBar(title = "My RFQs", onBack = onBack) },
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

                    state.noOrgWarning -> Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(Spacing.lg),
                    ) {
                        StatusBanner(
                            tone = StatusBannerTone.Warn,
                            leadingIcon = Icons.Outlined.WarningAmber,
                            title = "Organization not linked",
                            message = "Ask your admin to link your account to a hospital organization to post RFQs.",
                        )
                    }

                    state.rfqs.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.RequestQuote,
                        title = "No RFQs yet",
                        subtitle = "RFQs you post for bulk equipment will appear here.",
                    )

                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(horizontal = Spacing.lg, vertical = Spacing.md),
                        verticalArrangement = Arrangement.spacedBy(Spacing.md),
                    ) {
                        items(items = state.rfqs, key = { it.id }) { rfq ->
                            HospitalRfqRow(rfq = rfq, onClick = { onRfqClick(rfq.id) })
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun HospitalRfqRow(rfq: Rfq, onClick: () -> Unit) {
    val shape = MaterialTheme.shapes.large
    val source = rememberTapInteractionSource()
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(Surface0)
            .border(1.dp, Surface200, shape)
            .tapScale(source)
            .clickable(
                interactionSource = source,
                indication = null,
                onClick = onClick,
            )
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
                    style = MaterialTheme.typography.titleMedium,
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
                label = rfq.status.replaceFirstChar { c -> c.uppercase() },
                tone = if (rfq.isOpen) StatusTone.Info else StatusTone.Neutral,
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

        // Chip strip: budget · bid count · deadline
        Row(
            horizontalArrangement = Arrangement.spacedBy(Spacing.xs),
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth(),
        ) {
            formatBudget(rfq.budgetMinRupees, rfq.budgetMaxRupees)?.let { budget ->
                StatusChip(label = budget, tone = StatusTone.Success)
            }
            StatusChip(
                label = "${rfq.bidsCount} bid${if (rfq.bidsCount == 1) "" else "s"}",
                tone = StatusTone.Neutral,
            )
            rfq.deliveryDeadlineIso?.takeIf { it.isNotBlank() }?.let {
                StatusChip(label = "By $it", tone = StatusTone.Warn)
            }
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = "Qty ${rfq.quantity}",
                style = MaterialTheme.typography.labelMedium,
                color = Ink500,
            )
            rfq.createdAtInstant?.let {
                Text(
                    text = "Posted ${relativeLabel(it)} ago",
                    style = MaterialTheme.typography.labelMedium,
                    color = Ink500,
                )
            }
        }
    }
}

private fun formatBudget(min: Double?, max: Double?): String? = when {
    min != null && max != null && max > min -> "${formatRupees(min)} – ${formatRupees(max)}"
    max != null -> "Up to ${formatRupees(max)}"
    min != null -> "From ${formatRupees(min)}"
    else -> null
}
