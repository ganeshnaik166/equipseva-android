package com.equipseva.app.features.home.dashboards

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.Gavel
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.MedicalServices
import androidx.compose.material.icons.filled.MonitorHeart
import androidx.compose.material.icons.filled.Replay
import androidx.compose.material.icons.filled.ShoppingBag
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface100
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.designsystem.theme.Surface50

/**
 * Hospital-buyer home dashboard. Mirrors `screens-home.jsx HospitalHome`.
 *
 * Layout:
 *   1. Header: greeting + notification bell
 *   2. Primary CTA "Raise a repair request"
 *   3. 3-tile stat row (Active requests, Recent orders, Reorder)
 *   4. Active requests preview (2 cards)
 *   5. Staff activity feed (3 rows)
 */
@Composable
fun HospitalHome(
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

        PrimaryCallout(
            icon = Icons.Filled.Build,
            title = "Raise a repair request",
            subtitle = "Get bids from verified engineers.",
            onClick = { onCardClick("request_service") },
        )

        StatRow(
            tiles = listOf(
                StatTile(
                    icon = Icons.Filled.Build,
                    value = data.activeRequestsCount.toString(),
                    label = "Active requests",
                    hue = 150,
                    onClick = { onCardClick("active_jobs") },
                ),
                StatTile(
                    icon = Icons.Filled.LocalShipping,
                    value = data.recentOrdersCount.toString(),
                    label = "Recent orders",
                    hue = 40,
                    onClick = { onCardClick("order_history") },
                ),
                StatTile(
                    icon = Icons.Filled.Replay,
                    value = data.deliveredOrdersCount.toString(),
                    label = "Reorder",
                    hue = 200,
                    onClick = { onCardClick("browse_parts") },
                ),
            ),
        )

        DashboardSectionHeader(
            title = "Active requests",
            actionLabel = "View all",
            onAction = { onCardClick("active_jobs") },
        )

        ListCard(
            leadingIcon = Icons.Filled.MedicalServices,
            leadingHue = 150,
            title = "MRI 1.5T · GE Signa",
            subtitle = "Gradient coil issue · Radiology Wing",
            onClick = { onCardClick("active_jobs") },
        )

        ListCard(
            leadingIcon = Icons.Filled.MonitorHeart,
            leadingHue = 40,
            title = "ECG · Philips PageWriter TC70",
            subtitle = "Cable damage · Ward 3B",
            onClick = { onCardClick("active_jobs") },
        )

        DashboardSectionHeader(title = "Staff activity")

        Column(
            modifier = Modifier
                .padding(horizontal = Spacing.lg, vertical = Spacing.xs)
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(Surface0)
                .border(1.dp, Surface200, RoundedCornerShape(16.dp)),
        ) {
            ActivityRow(
                icon = Icons.Filled.Gavel,
                who = "Dr. Kumar",
                what = "approved bid from Ravi K.",
                when_ = "14m ago",
                showDivider = true,
            )
            ActivityRow(
                icon = Icons.Filled.ShoppingBag,
                who = "Nurse Asha",
                what = "ordered 40× ECG electrodes",
                when_ = "2h ago",
                showDivider = true,
            )
            ActivityRow(
                icon = Icons.Filled.Star,
                who = "Biomed. Sanjay",
                what = "rated engineer 5★",
                when_ = "1d ago",
                showDivider = false,
            )
        }

        DashboardSpacer(height = Spacing.xl)
    }
}

@Composable
private fun ActivityRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    who: String,
    what: String,
    when_: String,
    showDivider: Boolean,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 14.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(32.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(Surface50),
            contentAlignment = Alignment.Center,
        ) {
            Icon(imageVector = icon, contentDescription = null, tint = Ink700)
        }
        Row(modifier = Modifier.weight(1f)) {
            Text(
                text = who,
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
                color = Ink900,
            )
            Text(
                text = " $what",
                fontSize = 13.sp,
                color = Ink700,
            )
        }
        Text(text = when_, fontSize = 11.sp, color = Ink500)
    }
    if (showDivider) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp)
                .size(1.dp)
                .background(Surface100),
        )
    }
}
