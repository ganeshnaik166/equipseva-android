package com.equipseva.app.features.orders

import androidx.compose.foundation.background
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material.icons.outlined.ContentCopy
import androidx.compose.material.icons.outlined.Inventory
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedCard
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.data.orders.Order
import com.equipseva.app.core.data.orders.OrderLineItem
import com.equipseva.app.core.data.orders.OrderStatus
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.SectionHeader
import com.equipseva.app.designsystem.components.StatusChip
import com.equipseva.app.designsystem.components.StatusTone
import com.equipseva.app.designsystem.theme.Spacing

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OrderDetailScreen(
    onBack: () -> Unit,
    onShowMessage: (String) -> Unit = {},
    viewModel: OrderDetailViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text(state.order?.orderNumber?.let { "Order #$it" } ?: "Order") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    titleContentColor = MaterialTheme.colorScheme.onPrimary,
                    navigationIconContentColor = MaterialTheme.colorScheme.onPrimary,
                ),
            )
        },
    ) { inner ->
        when {
            state.loading -> Box(
                modifier = Modifier.padding(inner).fillMaxSize(),
                contentAlignment = Alignment.Center,
            ) { CircularProgressIndicator() }

            state.notFound -> Box(
                modifier = Modifier.padding(inner).fillMaxSize(),
            ) {
                EmptyStateView(
                    icon = Icons.Outlined.Inventory,
                    title = "Order not found",
                    subtitle = "It may have been removed or is not visible to you.",
                )
            }

            state.order != null -> OrderDetailBody(
                order = state.order!!,
                padding = inner,
                onShowMessage = onShowMessage,
                errorMessage = state.errorMessage,
            )

            else -> Column(Modifier.padding(inner).fillMaxSize()) {
                ErrorBanner(
                    message = state.errorMessage,
                    modifier = Modifier.padding(horizontal = Spacing.lg),
                )
            }
        }
    }
}

@Composable
private fun OrderDetailBody(
    order: Order,
    padding: PaddingValues,
    onShowMessage: (String) -> Unit,
    errorMessage: String?,
) {
    val clipboard = LocalClipboardManager.current
    LazyColumn(
        modifier = Modifier
            .padding(padding)
            .fillMaxSize(),
        contentPadding = PaddingValues(vertical = Spacing.md),
        verticalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        if (!errorMessage.isNullOrBlank()) {
            item("error") {
                ErrorBanner(
                    message = errorMessage,
                    modifier = Modifier.padding(horizontal = Spacing.lg),
                )
            }
        }

        item("header") {
            OrderHeaderCard(order)
        }

        item("timeline_header") {
            SectionHeader(title = "Progress", modifier = Modifier.padding(horizontal = Spacing.lg))
        }
        item("timeline") {
            OrderTimeline(
                currentStatus = order.status,
                modifier = Modifier
                    .padding(horizontal = Spacing.lg)
                    .fillMaxWidth(),
            )
        }

        item("ship_header") {
            SectionHeader(title = "Shipping", modifier = Modifier.padding(horizontal = Spacing.lg))
        }
        item("ship_card") { ShippingCard(order, clipboard, onShowMessage) }

        item("items_header") {
            SectionHeader(title = "Items", modifier = Modifier.padding(horizontal = Spacing.lg))
        }
        items(items = order.lineItems, key = { it.partId + it.name }) { line ->
            LineItemRow(line)
        }

        item("totals") { TotalsCard(order) }

        item("payment") { PaymentCard(order) }
    }
}

@Composable
private fun OrderHeaderCard(order: Order) {
    OutlinedCard(
        modifier = Modifier
            .padding(horizontal = Spacing.lg)
            .fillMaxWidth(),
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
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.SemiBold,
                )
                StatusChip(label = order.status.displayName, tone = order.status.toTone())
            }
            Text(
                text = "Placed on ${order.createdAtIso?.take(10) ?: "—"}",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                text = formatRupees(order.totalAmount),
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.primary,
            )
        }
    }
}

@Composable
private fun OrderTimeline(
    currentStatus: OrderStatus,
    modifier: Modifier = Modifier,
) {
    val steps = listOf(
        OrderStatus.PLACED to "Placed",
        OrderStatus.CONFIRMED to "Confirmed",
        OrderStatus.SHIPPED to "Shipped",
        OrderStatus.DELIVERED to "Delivered",
    )
    val reachedIndex = when (currentStatus) {
        OrderStatus.PLACED -> 0
        OrderStatus.CONFIRMED -> 1
        OrderStatus.SHIPPED -> 2
        OrderStatus.DELIVERED -> 3
        OrderStatus.CANCELLED, OrderStatus.RETURNED, OrderStatus.UNKNOWN -> -1
    }
    Row(
        modifier = modifier,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        steps.forEachIndexed { idx, step ->
            val reached = idx <= reachedIndex
            TimelineNode(reached = reached, label = step.second)
            if (idx < steps.size - 1) {
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(2.dp)
                        .background(
                            if (idx < reachedIndex) MaterialTheme.colorScheme.primary
                            else MaterialTheme.colorScheme.outlineVariant,
                        ),
                )
            }
        }
    }
}

@Composable
private fun TimelineNode(reached: Boolean, label: String) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            modifier = Modifier
                .size(24.dp)
                .clip(CircleShape)
                .background(
                    if (reached) MaterialTheme.colorScheme.primary
                    else MaterialTheme.colorScheme.surfaceVariant,
                ),
            contentAlignment = Alignment.Center,
        ) {
            if (reached) {
                Icon(
                    imageVector = Icons.Outlined.Check,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onPrimary,
                    modifier = Modifier.size(16.dp),
                )
            }
        }
        Spacer(Modifier.height(Spacing.xs))
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = if (reached) MaterialTheme.colorScheme.onSurface
            else MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun ShippingCard(
    order: Order,
    clipboard: androidx.compose.ui.platform.ClipboardManager,
    onShowMessage: (String) -> Unit,
) {
    OutlinedCard(
        modifier = Modifier
            .padding(horizontal = Spacing.lg)
            .fillMaxWidth(),
    ) {
        Column(
            modifier = Modifier.padding(Spacing.md),
            verticalArrangement = Arrangement.spacedBy(Spacing.xxs),
        ) {
            order.shippingAddress?.takeIf { it.isNotBlank() }?.let {
                Text(it, style = MaterialTheme.typography.bodyMedium)
            }
            order.locationLine?.let {
                Text(it, style = MaterialTheme.typography.bodyMedium)
            }
            order.shippingPincode?.takeIf { it.isNotBlank() }?.let {
                Text("PIN $it", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            order.trackingNumber?.takeIf { it.isNotBlank() }?.let { tracking ->
                Spacer(Modifier.height(Spacing.xxs))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = "Tracking: $tracking",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.weight(1f),
                    )
                    IconButton(onClick = {
                        clipboard.setText(AnnotatedString(tracking))
                        onShowMessage("Tracking number copied")
                    }) {
                        Icon(Icons.Outlined.ContentCopy, contentDescription = "Copy tracking")
                    }
                }
            }
            order.estimatedDelivery?.let {
                Text(
                    text = "Estimated delivery: $it",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun LineItemRow(line: OrderLineItem) {
    OutlinedCard(
        modifier = Modifier
            .padding(horizontal = Spacing.lg)
            .fillMaxWidth(),
        shape = RoundedCornerShape(Spacing.sm),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(Spacing.md),
            horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(Spacing.xxs)) {
                Text(line.name, style = MaterialTheme.typography.bodyLarge, maxLines = 2)
                line.partNumber?.let {
                    Text(it, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                Text(
                    "${line.quantity} × ${formatRupees(line.unitPriceRupees)}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Text(
                text = formatRupees(line.lineSubtotalRupees),
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.SemiBold,
            )
        }
    }
}

@Composable
private fun TotalsCard(order: Order) {
    OutlinedCard(
        modifier = Modifier
            .padding(horizontal = Spacing.lg)
            .fillMaxWidth(),
    ) {
        Column(
            modifier = Modifier.padding(Spacing.md),
            verticalArrangement = Arrangement.spacedBy(Spacing.xs),
        ) {
            TotalRow("Subtotal", formatRupees(order.subtotal))
            TotalRow("GST", formatRupees(order.gstAmount))
            TotalRow(
                "Shipping",
                if (order.shippingCost == 0.0) "Free" else formatRupees(order.shippingCost),
            )
            HorizontalDivider()
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text("Total", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                Text(
                    formatRupees(order.totalAmount),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.primary,
                )
            }
        }
    }
}

@Composable
private fun TotalRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(label, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value, style = MaterialTheme.typography.bodyMedium)
    }
}

@Composable
private fun PaymentCard(order: Order) {
    val tone = when (order.paymentStatus) {
        "completed" -> StatusTone.Success
        "failed" -> StatusTone.Danger
        "refunded" -> StatusTone.Info
        else -> StatusTone.Warn
    }
    OutlinedCard(
        modifier = Modifier
            .padding(horizontal = Spacing.lg, vertical = Spacing.xs)
            .fillMaxWidth(),
    ) {
        Column(
            modifier = Modifier.padding(Spacing.md),
            verticalArrangement = Arrangement.spacedBy(Spacing.xs),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("Payment", style = MaterialTheme.typography.titleMedium)
                StatusChip(
                    label = order.paymentStatus?.replaceFirstChar { it.uppercase() } ?: "Pending",
                    tone = tone,
                )
            }
            order.paymentId?.takeIf { it.isNotBlank() }?.let {
                Text(
                    "Ref: $it",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
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
