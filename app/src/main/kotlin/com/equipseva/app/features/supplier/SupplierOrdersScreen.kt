package com.equipseva.app.features.supplier

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
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.outlined.Inventory
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
import com.equipseva.app.core.data.orders.Order
import com.equipseva.app.core.data.orders.OrderStatus
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
fun SupplierOrdersScreen(
    onBack: () -> Unit,
    onOrderClick: (String) -> Unit,
    viewModel: SupplierOrdersViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Scaffold(
        topBar = { ESBackTopBar(title = "Incoming orders", onBack = onBack) },
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
                    state.noOrgWarning -> EmptyStateView(
                        icon = Icons.Outlined.Inventory,
                        title = "Organization not linked",
                        subtitle = "Ask your admin to link your account.",
                    )
                    state.orders.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.Inventory,
                        title = "No incoming orders",
                        subtitle = "Orders placed for your parts will appear here.",
                    )
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(horizontal = Spacing.lg, vertical = Spacing.md),
                        verticalArrangement = Arrangement.spacedBy(Spacing.md),
                    ) {
                        items(items = state.orders, key = { it.id }) { order ->
                            SupplierOrderCard(
                                order = order,
                                onClick = { onOrderClick(order.id) },
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SupplierOrderCard(
    order: Order,
    onClick: () -> Unit,
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() },
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
    ) {
        Column(
            modifier = Modifier.padding(Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = order.orderNumber?.let { "#$it" } ?: "Order",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                )
                StatusChip(
                    label = order.status.displayName,
                    tone = order.status.toTone(),
                )
            }
            val itemLine = if (order.lineItemCount == 1) "1 item" else "${order.lineItemCount} items"
            val placedLine = order.createdAtInstant?.let { "· Placed ${relativeLabel(it)} ago" }.orEmpty()
            Text(
                text = "$itemLine $placedLine".trimEnd(),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            order.locationLine?.let {
                Text(
                    text = "Ship to $it",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Text(
                text = formatRupees(order.totalAmount),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.primary,
            )
        }
    }
}

private fun OrderStatus.toTone(): StatusTone = when (this) {
    OrderStatus.PLACED, OrderStatus.CONFIRMED -> StatusTone.Info
    OrderStatus.SHIPPED -> StatusTone.Warn
    OrderStatus.DELIVERED -> StatusTone.Success
    OrderStatus.CANCELLED, OrderStatus.RETURNED -> StatusTone.Danger
    OrderStatus.UNKNOWN -> StatusTone.Neutral
}
