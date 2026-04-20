package com.equipseva.app.features.orders

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Inventory
import androidx.compose.material.icons.outlined.MedicalServices
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.data.orders.Order
import com.equipseva.app.core.data.orders.OrderLineItem
import com.equipseva.app.core.data.orders.OrderStatus
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.GradientTile
import com.equipseva.app.designsystem.components.SectionHeader
import com.equipseva.app.designsystem.components.StepperStep
import com.equipseva.app.designsystem.components.VerticalStepper
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface100
import com.equipseva.app.designsystem.theme.Surface200

@Composable
fun OrderDetailScreen(
    onBack: () -> Unit,
    onShowMessage: (String) -> Unit = {},
    viewModel: OrderDetailViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    var cancelDialogOpen by rememberSaveable { mutableStateOf(false) }

    LaunchedEffect(viewModel) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is OrderDetailViewModel.Effect.ShowMessage -> onShowMessage(effect.text)
            }
        }
    }

    Scaffold(
        topBar = {
            ESBackTopBar(
                title = state.order?.orderNumber?.let { "Order #$it" } ?: "Order",
                onBack = onBack,
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
                errorMessage = state.errorMessage ?: state.cancellationError,
                cancellationInFlight = state.cancellationInFlight,
                onRequestCancel = { cancelDialogOpen = true },
            )

            else -> Column(Modifier.padding(inner).fillMaxSize()) {
                ErrorBanner(
                    message = state.errorMessage,
                    modifier = Modifier.padding(horizontal = Spacing.lg),
                )
            }
        }
    }

    if (cancelDialogOpen) {
        AlertDialog(
            onDismissRequest = {
                if (!state.cancellationInFlight) cancelDialogOpen = false
            },
            title = { Text("Cancel this order?") },
            text = {
                Text("This cannot be undone. Any payment will be refunded per supplier policy.")
            },
            confirmButton = {
                TextButton(
                    enabled = !state.cancellationInFlight,
                    onClick = {
                        cancelDialogOpen = false
                        viewModel.onCancelOrder()
                    },
                    colors = ButtonDefaults.textButtonColors(
                        contentColor = MaterialTheme.colorScheme.error,
                    ),
                ) { Text("Cancel order") }
            },
            dismissButton = {
                TextButton(
                    enabled = !state.cancellationInFlight,
                    onClick = { cancelDialogOpen = false },
                ) { Text("Keep order") }
            },
        )
    }
}

@Composable
private fun OrderDetailBody(
    order: Order,
    padding: PaddingValues,
    errorMessage: String?,
    cancellationInFlight: Boolean,
    onRequestCancel: () -> Unit,
) {
    LazyColumn(
        modifier = Modifier
            .padding(padding)
            .fillMaxSize(),
        contentPadding = PaddingValues(vertical = Spacing.md),
        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        if (!errorMessage.isNullOrBlank()) {
            item("error") {
                ErrorBanner(
                    message = errorMessage,
                    modifier = Modifier.padding(horizontal = Spacing.lg),
                )
            }
        }

        item("timeline") { OrderTimelineCard(order) }

        item("items_header") { SectionHeader(title = "Items") }
        item("items_card") { OrderItemsCard(order) }

        item("delivery_header") { SectionHeader(title = "Delivery") }
        item("delivery_card") { DeliveryCard(order) }

        if (order.status == OrderStatus.PLACED || order.status == OrderStatus.CONFIRMED) {
            item("cancel") {
                OutlinedButton(
                    onClick = onRequestCancel,
                    enabled = !cancellationInFlight,
                    modifier = Modifier
                        .padding(horizontal = Spacing.lg, vertical = Spacing.sm)
                        .fillMaxWidth(),
                    colors = ButtonDefaults.outlinedButtonColors(
                        contentColor = MaterialTheme.colorScheme.error,
                    ),
                ) {
                    Text(if (cancellationInFlight) "Cancelling…" else "Cancel order")
                }
            }
        }
    }
}

@Composable
private fun OrderTimelineCard(order: Order) {
    val steps = buildList {
        add(StepperStep(title = "Paid · ${formatRupees(order.totalAmount)}", time = order.createdAtIso?.take(10)))
        add(StepperStep(title = "Packed at warehouse"))
        add(
            StepperStep(
                title = "Shipped" + (order.trackingNumber?.takeIf { it.isNotBlank() }?.let { " · $it" } ?: ""),
            ),
        )
        add(StepperStep(title = "Out for delivery", time = order.estimatedDelivery))
        add(StepperStep(title = "Delivered"))
    }
    val currentIndex = when (order.status) {
        OrderStatus.PLACED -> 0
        OrderStatus.CONFIRMED -> 1
        OrderStatus.SHIPPED -> 2
        OrderStatus.DELIVERED -> 4
        OrderStatus.CANCELLED, OrderStatus.RETURNED, OrderStatus.UNKNOWN -> -1
    }
    OutlinedSurfaceCard(modifier = Modifier.padding(horizontal = Spacing.lg)) {
        Column(modifier = Modifier.padding(Spacing.lg)) {
            VerticalStepper(steps = steps, current = currentIndex)
        }
    }
}

@Composable
private fun OrderItemsCard(order: Order) {
    OutlinedSurfaceCard(modifier = Modifier.padding(horizontal = Spacing.lg)) {
        if (order.lineItems.isEmpty()) {
            Text(
                text = "Line-item details weren't available for this order.",
                fontSize = 13.sp,
                color = Ink500,
                modifier = Modifier.padding(Spacing.md),
            )
        } else {
            Column {
                order.lineItems.forEachIndexed { i, line ->
                    LineItemRow(line = line)
                    if (i < order.lineItems.lastIndex) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(1.dp)
                                .background(Surface100),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun LineItemRow(line: OrderLineItem) {
    val (hue, icon) = iconFor(line.name)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(Spacing.md),
        horizontalArrangement = Arrangement.spacedBy(Spacing.md),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        GradientTile(icon = icon, hue = hue, size = 56.dp)
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = line.name,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = Ink900,
                maxLines = 2,
            )
            Text(
                text = "Qty ${line.quantity}",
                fontSize = 12.sp,
                color = Ink500,
                modifier = Modifier.padding(top = 2.dp),
            )
        }
        Text(
            text = formatRupees(line.lineSubtotalRupees),
            fontSize = 14.sp,
            fontWeight = FontWeight.Bold,
            color = Ink900,
        )
    }
}

@Composable
private fun DeliveryCard(order: Order) {
    OutlinedSurfaceCard(modifier = Modifier.padding(horizontal = Spacing.lg)) {
        Column(
            modifier = Modifier.padding(Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            val locationHeadline = order.locationLine?.takeIf { it.isNotBlank() } ?: "Delivery address"
            Text(
                text = locationHeadline,
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
                color = Ink900,
            )
            val addressParts = listOfNotNull(
                order.shippingAddress?.takeIf { it.isNotBlank() },
                order.shippingPincode?.takeIf { it.isNotBlank() }?.let { "PIN $it" },
            )
            if (addressParts.isNotEmpty()) {
                Text(
                    text = addressParts.joinToString(", "),
                    fontSize = 13.sp,
                    lineHeight = 18.sp,
                    color = Ink700,
                )
            }
        }
    }
}


@Composable
private fun OutlinedSurfaceCard(
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .background(
                color = MaterialTheme.colorScheme.surface,
                shape = MaterialTheme.shapes.medium,
            )
            .border(1.dp, Surface200, MaterialTheme.shapes.medium),
    ) {
        content()
    }
}

private fun iconFor(name: String): Pair<Int, ImageVector> {
    val n = name.lowercase()
    return when {
        "ecg" in n || "electrode" in n || "monitor" in n -> 40 to Icons.Outlined.MedicalServices
        "spo" in n || "sensor" in n -> 330 to Icons.Outlined.MedicalServices
        "mri" in n || "ct" in n || "x-ray" in n || "xray" in n || "ultrasound" in n -> 200 to Icons.Outlined.MedicalServices
        "pump" in n || "tubing" in n -> 280 to Icons.Outlined.MedicalServices
        "ventilator" in n -> 0 to Icons.Outlined.MedicalServices
        else -> 150 to Icons.Outlined.MedicalServices
    }
}
