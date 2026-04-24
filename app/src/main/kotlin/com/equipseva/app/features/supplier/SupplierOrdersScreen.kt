package com.equipseva.app.features.supplier

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Inventory
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.data.orders.Order
import com.equipseva.app.core.data.orders.OrderStatus
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.core.util.relativeLabel
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.PrimaryButton
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
fun SupplierOrdersScreen(
    onBack: () -> Unit,
    onOrderClick: (String) -> Unit,
    viewModel: SupplierOrdersViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val snackbarHost = remember { SnackbarHostState() }

    LaunchedEffect(Unit) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is SupplierOrdersViewModel.Effect.ShowMessage ->
                    snackbarHost.showSnackbar(effect.text)
            }
        }
    }

    Scaffold(
        topBar = { ESBackTopBar(title = "Incoming orders", onBack = onBack) },
        snackbarHost = { SnackbarHost(snackbarHost) },
        containerColor = Surface50,
    ) { inner ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(inner)
                .background(Surface50),
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
                        contentPadding = PaddingValues(
                            horizontal = Spacing.lg,
                            vertical = Spacing.md,
                        ),
                        verticalArrangement = Arrangement.spacedBy(Spacing.md),
                    ) {
                        items(items = state.orders, key = { it.id }) { order ->
                            SupplierOrderCard(
                                order = order,
                                acting = state.actingOrderId == order.id,
                                actionInProgress = state.actingOrderId != null,
                                onClick = { onOrderClick(order.id) },
                                onConfirm = { viewModel.onConfirmOrder(order) },
                                onMarkShipped = { viewModel.onMarkShipped(order) },
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
    acting: Boolean,
    actionInProgress: Boolean,
    onClick: () -> Unit,
    onConfirm: () -> Unit,
    onMarkShipped: () -> Unit,
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() },
        shape = RoundedCornerShape(8.dp),
        colors = CardDefaults.cardColors(containerColor = Surface0),
        border = BorderStroke(1.dp, Surface200),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
    ) {
        Column(
            modifier = Modifier.padding(Spacing.md),
            verticalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = order.orderNumber?.let { "#$it" } ?: "Order",
                    fontSize = 15.sp,
                    lineHeight = 20.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Ink900,
                )
                StatusChip(
                    label = order.status.displayName,
                    tone = order.status.toTone(),
                )
            }
            val itemLine = if (order.lineItemCount == 1) "1 item" else "${order.lineItemCount} items"
            val placedLine = order.createdAtInstant?.let { " · Placed ${relativeLabel(it)} ago" }.orEmpty()
            Text(
                text = "$itemLine$placedLine",
                fontSize = 12.sp,
                lineHeight = 16.sp,
                color = Ink500,
            )
            order.locationLine?.let {
                Text(
                    text = "Ship to $it",
                    fontSize = 12.sp,
                    lineHeight = 16.sp,
                    color = Ink500,
                )
            }
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = formatRupees(order.totalAmount),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = BrandGreenDark,
                )
                order.paymentStatus
                    ?.takeIf { it.isNotBlank() }
                    ?.let { raw ->
                        StatusChip(
                            label = raw.replaceFirstChar { it.uppercase() },
                            tone = raw.toPaymentTone(),
                        )
                    }
            }
            when (order.status) {
                OrderStatus.PLACED -> PrimaryButton(
                    label = "Confirm order",
                    loading = acting,
                    enabled = !actionInProgress,
                    onClick = onConfirm,
                )
                OrderStatus.CONFIRMED -> PrimaryButton(
                    label = "Mark shipped",
                    loading = acting,
                    enabled = !actionInProgress,
                    onClick = onMarkShipped,
                )
                else -> Unit
            }
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

private fun String.toPaymentTone(): StatusTone = when (lowercase()) {
    "paid", "captured", "authorized", "success" -> StatusTone.Success
    "pending", "created", "processing" -> StatusTone.Warn
    "failed", "cancelled", "refunded" -> StatusTone.Danger
    else -> StatusTone.Neutral
}
