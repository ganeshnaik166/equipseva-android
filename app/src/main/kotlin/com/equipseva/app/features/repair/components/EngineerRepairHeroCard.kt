package com.equipseva.app.features.repair.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Engineering
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.designsystem.theme.AccentLime
import com.equipseva.app.designsystem.theme.AccentLimeSoft
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreenDeep
import com.equipseva.app.designsystem.theme.Spacing

/**
 * Top-of-Repair-tab hero for engineers. Two pill stats sourced from existing
 * ViewModel state (nearby jobs + pending bids), plus quick-access links to
 * earnings and the profile editor (radius / specializations live there).
 */
@Composable
fun EngineerRepairHeroCard(
    nearbyCount: Int,
    pendingBidCount: Int,
    radiusKm: Int?,
    hasBase: Boolean,
    onViewEarnings: () -> Unit,
    onTuneProfile: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg, vertical = Spacing.sm)
            .clip(RoundedCornerShape(18.dp))
            .background(Brush.verticalGradient(listOf(BrandGreen, BrandGreenDeep)))
            .padding(Spacing.lg),
        verticalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(AccentLimeSoft),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Filled.Engineering, contentDescription = null, tint = BrandGreenDeep, modifier = Modifier.size(20.dp))
            }
            Column(modifier = Modifier.weight(1f)) {
                Text("Today's job board", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                Text(
                    text = when {
                        !hasBase -> "Set your service base in KYC to see distance"
                        radiusKm == null -> "All open jobs"
                        else -> "Within $radiusKm km of your base"
                    },
                    color = Color.White.copy(alpha = 0.85f),
                    fontSize = 12.sp,
                )
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
            StatPill(value = nearbyCount.toString(), label = "Nearby", modifier = Modifier.weight(1f))
            StatPill(value = pendingBidCount.toString(), label = "Pending bids", modifier = Modifier.weight(1f))
        }
        Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
            HeroLink(
                icon = Icons.Filled.Tune,
                label = "Tune service area",
                onClick = onTuneProfile,
            )
            HeroLink(
                icon = Icons.AutoMirrored.Filled.ArrowForward,
                label = "View earnings",
                onClick = onViewEarnings,
                arrowTrailing = false,
            )
        }
    }
}

@Composable
private fun StatPill(value: String, label: String, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White.copy(alpha = 0.13f))
            .padding(vertical = 10.dp, horizontal = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Text(value, color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold)
        Text(label.uppercase(), color = Color.White.copy(alpha = 0.85f), fontSize = 10.sp, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun HeroLink(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    onClick: () -> Unit,
    arrowTrailing: Boolean = true,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .clip(RoundedCornerShape(8.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 4.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        if (!arrowTrailing) {
            Text(label, color = AccentLime, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.width(2.dp))
            Icon(icon, contentDescription = null, tint = AccentLime, modifier = Modifier.size(14.dp))
        } else {
            Icon(icon, contentDescription = null, tint = AccentLime, modifier = Modifier.size(14.dp))
            Spacer(Modifier.width(2.dp))
            Text(label, color = AccentLime, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
        }
    }
}
