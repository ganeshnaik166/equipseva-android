package com.equipseva.app.features.supplier

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
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.outlined.RequestQuote
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
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
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.core.util.relativeLabel
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.StatusChip
import com.equipseva.app.designsystem.components.StatusTone
import com.equipseva.app.designsystem.theme.Spacing

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SupplierRfqsScreen(
    onBack: () -> Unit,
    viewModel: SupplierRfqsViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Scaffold(
        topBar = { ESBackTopBar(title = "Open RFQs", onBack = onBack) },
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
                    state.rfqs.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.RequestQuote,
                        title = "No open RFQs",
                        subtitle = "Check back later for new bulk inquiries.",
                    )
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(horizontal = Spacing.lg, vertical = Spacing.md),
                        verticalArrangement = Arrangement.spacedBy(Spacing.md),
                    ) {
                        items(items = state.rfqs, key = { it.id }) { rfq ->
                            RfqListCard(rfq = rfq)
                        }
                    }
                }
            }
        }
    }
}

@Composable
internal fun RfqListCard(rfq: Rfq) {
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
                Text(
                    text = it,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            val budget = formatBudget(rfq.budgetMinRupees, rfq.budgetMaxRupees)
            if (budget != null) {
                Text(
                    text = "Budget $budget",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            val posted = rfq.createdAtInstant?.let { "· Posted ${relativeLabel(it)} ago" } ?: ""
            Text(
                text = "Qty ${rfq.quantity} · ${rfq.bidsCount} bid(s) $posted".trimEnd(),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

internal fun formatBudget(min: Double?, max: Double?): String? = when {
    min != null && max != null && max > min -> "${formatRupees(min)} – ${formatRupees(max)}"
    max != null -> "up to ${formatRupees(max)}"
    min != null -> "from ${formatRupees(min)}"
    else -> null
}
