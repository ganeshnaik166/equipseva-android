package com.equipseva.app.features.home.dashboards

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Assignment
import androidx.compose.material.icons.automirrored.filled.TrendingUp
import androidx.compose.material.icons.filled.Analytics
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.Payments
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface50

/**
 * Manufacturer home dashboard. No Claude-Design ref — analytics-leaning
 * shape using the shared dashboard primitives.
 */
@Composable
fun ManufacturerHome(
    name: String,
    organization: String?,
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
            eyebrow = "Win rate (30 days)",
            bigValue = "42",
            valueSuffix = "% of bids accepted",
            body = "Tap into analytics to see win-rate trends, top categories, and pipeline value.",
            cta = "Open analytics",
            onClick = { onCardClick("analytics") },
        )

        StatRow(
            tiles = listOf(
                StatTile(
                    icon = Icons.AutoMirrored.Filled.Assignment,
                    value = "12",
                    label = "RFQs assigned",
                    hue = 280,
                    onClick = { onCardClick("rfqs_assigned") },
                ),
                StatTile(
                    icon = Icons.AutoMirrored.Filled.TrendingUp,
                    value = "₹3.4L",
                    label = "Pipeline",
                    hue = 200,
                    onClick = { onCardClick("lead_pipeline") },
                ),
                StatTile(
                    icon = Icons.Filled.Payments,
                    value = "₹1.1L",
                    label = "Revenue MTD",
                    hue = 150,
                    onClick = { onCardClick("analytics") },
                ),
            ),
        )

        DashboardSectionHeader(
            title = "Top equipment categories",
            actionLabel = "Analytics",
            onAction = { onCardClick("analytics") },
        )
        ListCard(
            leadingIcon = Icons.Filled.Analytics,
            leadingHue = 150,
            title = "Imaging & radiology",
            subtitle = "62% of awarded bids this month",
            trailing = "Top",
            onClick = { onCardClick("analytics") },
        )
        ListCard(
            leadingIcon = Icons.Filled.Analytics,
            leadingHue = 200,
            title = "Patient monitoring",
            subtitle = "23% — growing",
            trailing = "+8%",
            onClick = { onCardClick("analytics") },
        )
        ListCard(
            leadingIcon = Icons.Filled.Analytics,
            leadingHue = 40,
            title = "Surgical equipment",
            subtitle = "9% — flat",
            trailing = "0%",
            onClick = { onCardClick("analytics") },
        )

        DashboardSectionHeader(title = "Today's tip")
        TipCard(
            icon = Icons.Filled.Lightbulb,
            title = "Respond within 24 hours to RFQs",
            body = "Manufacturers who respond same-day win 2× more bids. Set up notification alerts so nothing slips.",
        )

        DashboardSpacer(height = Spacing.xl)
    }
}
