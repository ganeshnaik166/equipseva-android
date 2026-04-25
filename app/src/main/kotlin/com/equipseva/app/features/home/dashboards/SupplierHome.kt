package com.equipseva.app.features.home.dashboards

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.ShoppingCart
import androidx.compose.material.icons.filled.Store
import androidx.compose.material.icons.filled.Warning
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface50

/**
 * Supplier home dashboard. No Claude-Design ref for this persona — laid
 * out with the shared dashboard primitives so the visual language matches
 * Hospital + Engineer.
 */
@Composable
fun SupplierHome(
    name: String,
    organization: String?,
    data: com.equipseva.app.features.home.HomeViewModel.DashboardData,
    onCardClick: (key: String) -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Surface50)
            .verticalScroll(rememberScrollState()),
    ) {
        DashboardHeader(
            name = name,
            subtitle = organization,
            onOpenNotifications = { onCardClick("notifications") },
        )

        GradientHero(
            eyebrow = "Today's revenue",
            bigValue = formatRupees(data.todayRevenueRupees),
            valueSuffix = "across ${data.pendingOrdersCount + data.listingsCount} listings",
            body = "Tap to see fulfilment status and pending shipments.",
            cta = "View orders",
            onClick = { onCardClick("incoming_orders") },
        )

        StatRow(
            tiles = listOf(
                StatTile(
                    icon = Icons.Filled.ShoppingCart,
                    value = data.pendingOrdersCount.toString(),
                    label = "Pending orders",
                    hue = 150,
                    onClick = { onCardClick("incoming_orders") },
                ),
                StatTile(
                    icon = Icons.Filled.Warning,
                    value = data.stockAlertsCount.toString(),
                    label = "Stock alerts",
                    hue = 0,
                    onClick = { onCardClick("stock_alerts") },
                ),
                StatTile(
                    icon = Icons.Filled.Description,
                    value = data.rfqInboxCount.toString(),
                    label = "RFQ inbox",
                    hue = 280,
                    onClick = { onCardClick("rfqs") },
                ),
            ),
        )

        DashboardSectionHeader(
            title = "Top listings",
            actionLabel = "View all",
            onAction = { onCardClick("my_listings") },
        )
        ListCard(
            leadingIcon = Icons.Filled.Store,
            leadingHue = 200,
            title = "Philips IntelliVue probes (10 SKUs)",
            subtitle = "32 sold this week",
            trailing = "₹12.4k",
            onClick = { onCardClick("my_listings") },
        )
        ListCard(
            leadingIcon = Icons.Filled.Inventory2,
            leadingHue = 40,
            title = "GE ECG electrodes",
            subtitle = "Low stock — 18 units left",
            trailing = "Reorder",
            onClick = { onCardClick("stock_alerts") },
        )

        DashboardSectionHeader(title = "Tips for sellers")
        TipCard(
            icon = Icons.Filled.Store,
            title = "Add an OEM badge to win RFQs faster",
            body = "Hospitals shortlist OEM-tagged listings 3× more often. Edit a listing and toggle the OEM flag on.",
        )

        DashboardSpacer(height = Spacing.xl)
    }
}
