package com.equipseva.app.features.home.dashboards

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Engineering
import androidx.compose.material.icons.filled.Gavel
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.Payments
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.designsystem.theme.BrandGreen50
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface50

/**
 * Engineer home dashboard. Mirrors `screens-home.jsx EngineerHome`.
 *
 * Layout:
 *   1. Header: greeting + notification bell
 *   2. KYC banner (when not verified) OR verified pill
 *   3. Gradient hero: "Available jobs nearby" big number
 *   4. 3-tile dashboard (Active work, My bids, Earnings)
 *   5. Today's schedule preview (2 rows with NOW/upcoming time pill)
 *   6. Tip-of-the-day card
 */
@Composable
fun EngineerHome(
    name: String,
    verified: Boolean,
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

        if (!verified) {
            KycBanner(onClick = { onCardClick("kyc") })
        } else {
            KycVerifiedPill()
        }

        GradientHero(
            eyebrow = "Available jobs nearby",
            bigValue = data.nearbyJobsCount.toString(),
            valueSuffix = "within 10 km",
            body = "Tap to view feed, place bids, and earn.",
            cta = "View feed",
            onClick = { onCardClick("jobs_nearby") },
        )

        StatRow(
            tiles = listOf(
                StatTile(
                    icon = Icons.Filled.Engineering,
                    value = data.activeWorkCount.toString(),
                    label = "Active work",
                    hue = 150,
                    onClick = { onCardClick("active_work") },
                ),
                StatTile(
                    icon = Icons.Filled.Gavel,
                    value = data.myBidsCount.toString(),
                    label = "My bids",
                    hue = 40,
                    onClick = { onCardClick("my_bids") },
                ),
                StatTile(
                    icon = Icons.Filled.Payments,
                    value = formatRupees(data.earningsRupees),
                    label = "Earnings",
                    hue = 200,
                    onClick = { onCardClick("earnings") },
                ),
            ),
        )

        DashboardSectionHeader(title = "Today's schedule")
        ScheduleRow(
            timeBadge = "NOW",
            timeValue = "11:30",
            highlighted = true,
            title = "Apollo Greams · CT scanner",
            subtitle = "Tube overheating · 3.2 km away",
            statusLabel = "En route",
            onClick = { onCardClick("active_work") },
        )
        ScheduleRow(
            timeBadge = "3:00",
            timeValue = "PM",
            highlighted = false,
            title = "MIOT · ECG repair",
            subtitle = "Cable damage · 5.1 km away",
            statusLabel = "Accepted",
            onClick = { onCardClick("active_work") },
        )

        DashboardSectionHeader(title = "Tip of the day")
        TipCard(
            icon = Icons.Filled.Lightbulb,
            title = "Snap before you leave",
            body = "Photos of repair outcome boost your rating by 22% and unlock faster payouts.",
        )

        DashboardSpacer(height = Spacing.xl)
    }
}

@Composable
private fun ScheduleRow(
    timeBadge: String,
    timeValue: String,
    highlighted: Boolean,
    title: String,
    subtitle: String,
    statusLabel: String,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg, vertical = 4.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(com.equipseva.app.designsystem.theme.Surface0)
            .clickable(onClick = onClick)
            .padding(14.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(
            modifier = Modifier
                .width(52.dp)
                .clip(RoundedCornerShape(10.dp))
                .let { if (highlighted) it.background(BrandGreen50) else it }
                .padding(vertical = 6.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            Text(
                text = timeBadge,
                fontSize = 10.sp,
                fontWeight = FontWeight.Bold,
                color = if (highlighted) BrandGreenDark else Ink500,
                letterSpacing = 0.4.sp,
            )
            Text(
                text = timeValue,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                color = if (highlighted) BrandGreenDark else Ink900,
            )
        }
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(text = title, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = Ink900)
            Text(text = subtitle, fontSize = 12.sp, color = Ink500)
        }
        Box(
            modifier = Modifier
                .clip(RoundedCornerShape(999.dp))
                .background(BrandGreen50)
                .padding(horizontal = 10.dp, vertical = 4.dp),
        ) {
            Text(
                text = statusLabel,
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                color = BrandGreenDark,
            )
        }
    }
}
