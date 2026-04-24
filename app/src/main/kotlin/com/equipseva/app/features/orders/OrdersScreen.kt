package com.equipseva.app.features.orders

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ContentCopy
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
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.data.orders.Order
import com.equipseva.app.core.data.orders.OrderStatus
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.designsystem.components.ESTopBar
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.StatusChip
import com.equipseva.app.designsystem.components.StatusTone
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.Ink300
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface200
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

private enum class OrdersTab(val label: String) {
    All("All"),
    Active("Active"),
    Delivered("Delivered"),
    Cancelled("Cancelled"),
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OrdersScreen(
    onShowMessage: (String) -> Unit = {},
    onOrderClick: (String) -> Unit = {},
    onShopMarketplace: () -> Unit = {},
    viewModel: OrdersViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val listState = rememberLazyListState()
    var selectedTab by rememberSaveable { mutableStateOf(OrdersTab.All) }

    val reachedEnd by remember {
        derivedStateOf {
            val last = listState.layoutInfo.visibleItemsInfo.lastOrNull()
            val total = listState.layoutInfo.totalItemsCount
            last != null && total > 0 && last.index >= total - 3
        }
    }

    LaunchedEffect(reachedEnd, state.items.size) {
        if (reachedEnd) viewModel.onReachEnd()
    }

    val filtered = remember(state.items, selectedTab) {
        when (selectedTab) {
            OrdersTab.All -> state.items
            OrdersTab.Active -> state.items.filter {
                it.status == OrderStatus.PLACED ||
                    it.status == OrderStatus.CONFIRMED ||
                    it.status == OrderStatus.SHIPPED
            }
            OrdersTab.Delivered -> state.items.filter { it.status == OrderStatus.DELIVERED }
            OrdersTab.Cancelled -> state.items.filter {
                it.status == OrderStatus.CANCELLED || it.status == OrderStatus.RETURNED
            }
        }
    }

    Scaffold(topBar = { ESTopBar(title = "Orders") }) { inner ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(inner),
        ) {
            OrdersTabBar(selected = selectedTab, onSelect = { selectedTab = it })
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
                    state.initialLoading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                    filtered.isEmpty() -> EmptyOrders(onShopMarketplace = onShopMarketplace)
                    else -> LazyColumn(
                        state = listState,
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(horizontal = Spacing.lg, vertical = Spacing.md),
                        verticalArrangement = Arrangement.spacedBy(Spacing.md),
                    ) {
                        items(items = filtered, key = { it.id }) { order ->
                            OrderCard(
                                order = order,
                                onShowMessage = onShowMessage,
                                onClick = { onOrderClick(order.id) },
                            )
                        }
                        if (state.loadingMore) {
                            item("loading_more") {
                                Box(
                                    modifier = Modifier.fillMaxWidth().padding(Spacing.md),
                                    contentAlignment = Alignment.Center,
                                ) {
                                    CircularProgressIndicator(modifier = Modifier.size(24.dp), strokeWidth = 2.dp)
                                }
                            }
                        } else if (state.endReached && state.items.isNotEmpty()) {
                            item("end") {
                                Text(
                                    text = "No more orders to show.",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(Spacing.md),
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun OrdersTabBar(
    selected: OrdersTab,
    onSelect: (OrdersTab) -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surface)
            .border(1.dp, Surface200)
            .padding(horizontal = Spacing.lg),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            OrdersTab.entries.forEach { tab ->
                OrdersTabPill(
                    label = tab.label,
                    selected = tab == selected,
                    onClick = { onSelect(tab) },
                )
            }
        }
    }
}

@Composable
private fun OrdersTabPill(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
) {
    Column(
        modifier = Modifier
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = label,
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = if (selected) BrandGreenDark else Ink500,
        )
        Box(
            modifier = Modifier
                .padding(top = 8.dp)
                .height(2.dp)
                .fillMaxWidth()
                .background(if (selected) BrandGreen else androidx.compose.ui.graphics.Color.Transparent),
        )
    }
}

@Composable
private fun OrderCard(
    order: Order,
    onShowMessage: (String) -> Unit,
    onClick: () -> Unit,
) {
    val clipboardManager = LocalClipboardManager.current
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() },
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
    ) {
        Column(
            modifier = Modifier.padding(Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                order.orderNumber?.let { num ->
                    Text(
                        text = num,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 0.3.sp,
                        color = Ink700,
                    )
                }
                formatOrderDate(order.createdAtIso)?.let { date ->
                    Box(
                        modifier = Modifier
                            .size(3.dp)
                            .background(Ink300, CircleShape),
                    )
                    Text(
                        text = date,
                        fontSize = 12.sp,
                        color = Ink500,
                    )
                }
                Box(Modifier.weight(1f))
                StatusChip(
                    label = order.status.displayName,
                    tone = order.status.toTone(),
                )
            }
            val itemLine = if (order.lineItemCount == 1) "1 item" else "${order.lineItemCount} items"
            Text(
                text = itemLine,
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
            order.trackingNumber?.takeIf { it.isNotBlank() }?.let { tracking ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = "Tracking: $tracking",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.weight(1f),
                    )
                    IconButton(
                        onClick = {
                            clipboardManager.setText(AnnotatedString(tracking))
                            onShowMessage("Tracking number copied")
                        },
                    ) {
                        Icon(
                            imageVector = Icons.Outlined.ContentCopy,
                            contentDescription = "Copy tracking number",
                        )
                    }
                }
            }
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = formatRupees(order.totalAmount),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.primary,
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

private val orderDateFormatter = DateTimeFormatter.ofPattern("d MMM", Locale.ENGLISH)

private fun formatOrderDate(iso: String?): String? {
    if (iso.isNullOrBlank() || iso.length < 10) return null
    return runCatching {
        LocalDate.parse(iso.substring(0, 10)).format(orderDateFormatter)
    }.getOrNull()
}

@Composable
private fun EmptyOrders(onShopMarketplace: () -> Unit) {
    EmptyStateView(
        icon = Icons.Outlined.Inventory,
        title = "No orders yet",
        subtitle = "Completed purchases will appear here.",
        ctaLabel = "Shop marketplace",
        onCta = onShopMarketplace,
    )
}
