package com.equipseva.app.features.home.dashboards

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.Map
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface50

/**
 * Logistics partner home dashboard. No Claude-Design ref — operations-
 * leaning shape using the shared dashboard primitives.
 */
@Composable
fun LogisticsHome(
    name: String,
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
            onOpenNotifications = { onCardClick("notifications") },
        )

        GradientHero(
            eyebrow = "Today",
            bigValue = data.activeDeliveriesCount.toString(),
            valueSuffix = "deliveries to wrap",
            body = "Tap to start your route and see live pickup queue.",
            cta = "Start route",
            onClick = { onCardClick("active_deliveries") },
        )

        StatRow(
            tiles = listOf(
                StatTile(
                    icon = Icons.Filled.Inventory2,
                    value = data.pickupQueueCount.toString(),
                    label = "Pickup queue",
                    hue = 40,
                    onClick = { onCardClick("pickup_queue") },
                ),
                StatTile(
                    icon = Icons.Filled.LocalShipping,
                    value = data.activeDeliveriesCount.toString(),
                    label = "Active",
                    hue = 200,
                    onClick = { onCardClick("active_deliveries") },
                ),
                StatTile(
                    icon = Icons.Filled.CheckCircle,
                    value = data.completedTodayCount.toString(),
                    label = "Completed today",
                    hue = 150,
                    onClick = { onCardClick("completed_today") },
                ),
            ),
        )

        DashboardSectionHeader(
            title = "Next pickups",
            actionLabel = "View queue",
            onAction = { onCardClick("pickup_queue") },
        )
        ListCard(
            leadingIcon = Icons.Filled.Map,
            leadingHue = 40,
            title = "Apollo Greams → Velachery",
            subtitle = "ECG monitor · 8.4 km · 18 min",
            trailing = "Pickup",
            onClick = { onCardClick("pickup_queue") },
        )
        ListCard(
            leadingIcon = Icons.Filled.Map,
            leadingHue = 200,
            title = "MIOT → Tambaram",
            subtitle = "Spare parts × 4 · 12.1 km · 26 min",
            trailing = "Pickup",
            onClick = { onCardClick("pickup_queue") },
        )

        DashboardSectionHeader(title = "Driver tip")
        TipCard(
            icon = Icons.Filled.Lightbulb,
            title = "Snap a delivery photo to close jobs faster",
            body = "Hospitals confirm receipt 3× faster when a delivery photo is attached. Tap the camera on Active deliveries.",
        )

        DashboardSpacer(height = Spacing.xl)
    }
}
