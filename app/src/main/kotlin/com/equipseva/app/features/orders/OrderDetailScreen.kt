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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CloudDownload
import androidx.compose.material.icons.outlined.Inventory
import androidx.compose.material.icons.outlined.MedicalServices
import android.content.Intent
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.outlined.ContentCopy
import android.widget.Toast
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil3.compose.AsyncImage
import com.equipseva.app.core.data.orders.Order
import com.equipseva.app.core.data.orders.OrderLineItem
import com.equipseva.app.core.data.orders.OrderStatus
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.designsystem.components.CancelOrderSheet
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.GradientTile
import com.equipseva.app.designsystem.components.SecureScreen
import com.equipseva.app.designsystem.components.SectionHeader
import com.equipseva.app.designsystem.components.StepperStep
import com.equipseva.app.designsystem.components.VerticalStepper
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface100
import com.equipseva.app.designsystem.theme.Surface200

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OrderDetailScreen(
    onBack: () -> Unit,
    onShowMessage: (String) -> Unit = {},
    onRateOrder: (String) -> Unit = {},
    viewModel: OrderDetailViewModel = hiltViewModel(),
) {
    SecureScreen()
    val state by viewModel.state.collectAsStateWithLifecycle()
    val context = LocalContext.current

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
                actions = {
                    val order = state.order
                    if (order != null) {
                        val clipboard = LocalClipboardManager.current
                        order.orderNumber?.takeIf { it.isNotBlank() }?.let { num ->
                            IconButton(onClick = {
                                clipboard.setText(AnnotatedString(num))
                                Toast.makeText(context, "Order number copied", Toast.LENGTH_SHORT).show()
                            }) {
                                Icon(Icons.Outlined.ContentCopy, contentDescription = "Copy order number")
                            }
                        }
                        IconButton(onClick = {
                            val shareText = buildString {
                                append("Order #${order.orderNumber}")
                                append("\nStatus: ${order.status.name.lowercase().replaceFirstChar { it.uppercase() }}")
                                append("\nTotal: ${formatRupees(order.totalAmount)}")
                                append("\n\nShared from EquipSeva")
                            }
                            val intent = Intent(Intent.ACTION_SEND).apply {
                                type = "text/plain"
                                putExtra(Intent.EXTRA_SUBJECT, "Order #${order.orderNumber}")
                                putExtra(Intent.EXTRA_TEXT, shareText)
                            }
                            context.startActivity(Intent.createChooser(intent, "Share order"))
                        }) {
                            Icon(Icons.Filled.Share, contentDescription = "Share")
                        }
                    }
                },
            )
        },
    ) { inner ->
        PullToRefreshBox(
            isRefreshing = state.refreshing,
            onRefresh = viewModel::refresh,
            modifier = Modifier.padding(inner).fillMaxSize(),
        ) {
            when {
                state.loading -> Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center,
                ) { CircularProgressIndicator() }

                state.notFound -> Box(
                    modifier = Modifier.fillMaxSize(),
                ) {
                    EmptyStateView(
                        icon = Icons.Outlined.Inventory,
                        title = "Order not found",
                        subtitle = "It may have been removed or is not visible to you.",
                    )
                }

                state.order != null -> OrderDetailBody(
                    order = state.order!!,
                    padding = PaddingValues(0.dp),
                    errorMessage = state.errorMessage ?: state.cancellationError,
                    cancellationInFlight = state.cancellationInFlight,
                    canRateOrder = state.canRateOrder,
                    onRequestCancel = viewModel::onRequestCancel,
                    onRateOrder = { onRateOrder(state.order!!.id) },
                    onDownloadInvoice = viewModel::onDownloadInvoice,
                )

                else -> Column(Modifier.fillMaxSize()) {
                    ErrorBanner(
                        message = state.errorMessage,
                        modifier = Modifier.padding(horizontal = Spacing.lg),
                    )
                }
            }
        }
    }

    if (state.cancelSheetOpen) {
        CancelOrderSheet(
            reason = state.cancelReasonDraft,
            cancelling = state.cancellationInFlight,
            onReasonChange = viewModel::onCancelReasonChange,
            onConfirm = viewModel::onConfirmCancel,
            onDismiss = viewModel::onDismissCancelSheet,
        )
    }
}

@Composable
private fun OrderDetailBody(
    order: Order,
    padding: PaddingValues,
    errorMessage: String?,
    cancellationInFlight: Boolean,
    canRateOrder: Boolean,
    onRequestCancel: () -> Unit,
    onRateOrder: () -> Unit,
    onDownloadInvoice: () -> Unit,
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

        item("summary_header") { SectionHeader(title = "Order summary") }
        item("summary_card") { OrderSummaryCard(order, onDownloadInvoice = onDownloadInvoice) }

        item("delivery_header") { SectionHeader(title = "Delivery") }
        item("delivery_card") { DeliveryCard(order) }

        val notes = order.notes?.takeIf { it.isNotBlank() }
        if (notes != null) {
            item("notes_header") { SectionHeader(title = "Notes") }
            item("notes_card") { NotesCard(notes) }
        }

        if (canRateOrder) {
            item("rate") {
                OutlinedButton(
                    onClick = onRateOrder,
                    modifier = Modifier
                        .padding(horizontal = Spacing.lg, vertical = Spacing.sm)
                        .fillMaxWidth(),
                ) {
                    Text("Rate this order")
                }
            }
        }

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
        add(StepperStep(title = "Delivered", time = order.deliveredAtIso?.take(10)))
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
        val imageUrl = line.imageUrl?.takeIf { it.isNotBlank() }
        if (imageUrl != null) {
            AsyncImage(
                model = imageUrl,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .size(56.dp)
                    .clip(MaterialTheme.shapes.small),
            )
        } else {
            GradientTile(icon = icon, hue = hue, size = 56.dp)
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = line.name,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = Ink900,
                maxLines = 2,
            )
            line.partNumber?.takeIf { it.isNotBlank() }?.let {
                Text(
                    text = "Part #$it",
                    fontSize = 11.sp,
                    color = Ink500,
                    modifier = Modifier.padding(top = 2.dp),
                )
            }
            Text(
                text = "Qty ${line.quantity} · ${formatRupees(line.unitPriceRupees)} each",
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
    val context = LocalContext.current
    val fullAddress = listOfNotNull(
        order.locationLine?.takeIf { it.isNotBlank() },
        order.shippingAddress?.takeIf { it.isNotBlank() },
        order.shippingPincode?.takeIf { it.isNotBlank() },
    ).joinToString(", ")

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
            if (fullAddress.isNotBlank()) {
                OutlinedButton(
                    onClick = {
                        val encoded = java.net.URLEncoder.encode(fullAddress, Charsets.UTF_8.name())
                        val intent = Intent(
                            Intent.ACTION_VIEW,
                            android.net.Uri.parse("geo:0,0?q=$encoded"),
                        )
                        runCatching { context.startActivity(intent) }
                    },
                    modifier = Modifier.padding(top = Spacing.sm),
                ) {
                    Text("View on map")
                }
            }
        }
    }
}


@Composable
private fun NotesCard(notes: String) {
    OutlinedSurfaceCard(modifier = Modifier.padding(horizontal = Spacing.lg)) {
        Text(
            text = notes,
            fontSize = 13.sp,
            lineHeight = 18.sp,
            color = Ink700,
            modifier = Modifier.padding(Spacing.lg),
        )
    }
}

@Composable
private fun OrderSummaryCard(order: Order, onDownloadInvoice: () -> Unit) {
    OutlinedSurfaceCard(modifier = Modifier.padding(horizontal = Spacing.lg)) {
        Column(
            modifier = Modifier.padding(Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            SummaryRow(label = "Subtotal", value = formatRupees(order.subtotal))
            if (order.gstAmount > 0.0) {
                SummaryRow(label = "GST", value = formatRupees(order.gstAmount))
            }
            if (order.shippingCost > 0.0) {
                SummaryRow(label = "Shipping", value = formatRupees(order.shippingCost))
            }
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(1.dp)
                    .background(Surface100),
            )
            SummaryRow(
                label = "Total",
                value = formatRupees(order.totalAmount),
                emphasized = true,
            )
            val paymentLabel = order.paymentStatus?.takeIf { it.isNotBlank() }
                ?.replaceFirstChar { it.uppercase() }
            if (paymentLabel != null) {
                Text(
                    text = "Payment · $paymentLabel",
                    fontSize = 12.sp,
                    color = Ink500,
                    modifier = Modifier.padding(top = 4.dp),
                )
            }
            if (order.paymentStatus.equals("completed", ignoreCase = true)) {
                Spacer(Modifier.height(8.dp))
                OutlinedButton(
                    onClick = onDownloadInvoice,
                    modifier = Modifier.fillMaxWidth(),
                    enabled = !order.invoiceUrl.isNullOrBlank(),
                ) {
                    Icon(
                        imageVector = Icons.Filled.CloudDownload,
                        contentDescription = null,
                        modifier = Modifier.size(18.dp),
                    )
                    Spacer(Modifier.size(Spacing.sm))
                    Text(
                        if (order.invoiceUrl.isNullOrBlank()) "Invoice generating…" else "Download invoice",
                    )
                }
            }
        }
    }
}

@Composable
private fun SummaryRow(label: String, value: String, emphasized: Boolean = false) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = label,
            fontSize = if (emphasized) 14.sp else 13.sp,
            fontWeight = if (emphasized) FontWeight.Bold else FontWeight.Normal,
            color = if (emphasized) Ink900 else Ink700,
        )
        Text(
            text = value,
            fontSize = if (emphasized) 14.sp else 13.sp,
            fontWeight = if (emphasized) FontWeight.Bold else FontWeight.SemiBold,
            color = if (emphasized) Ink900 else Ink700,
        )
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
