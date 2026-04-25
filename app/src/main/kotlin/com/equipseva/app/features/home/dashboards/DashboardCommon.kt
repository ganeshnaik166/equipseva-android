package com.equipseva.app.features.home.dashboards

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowForward
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.outlined.VerifiedUser
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreen50
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Success
import com.equipseva.app.designsystem.theme.SuccessBg
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.designsystem.theme.Surface50
import com.equipseva.app.designsystem.theme.Warning
import com.equipseva.app.designsystem.theme.WarningBg

/**
 * Greeting strip: avatar (initial) + good-morning + name on the left,
 * notification bell on the right. Lives at the very top of every role
 * dashboard, mirroring the design `screens-home.jsx` header rows.
 */
@Composable
internal fun DashboardHeader(
    name: String,
    subtitle: String? = null,
    onOpenNotifications: () -> Unit = {},
    hasUnread: Boolean = true,
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(Surface0)
            .border(1.dp, Surface200)
            .padding(start = Spacing.lg, end = Spacing.lg, top = 8.dp, bottom = Spacing.lg),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    modifier = Modifier
                        .size(40.dp)
                        .clip(CircleShape)
                        .background(BrandGreenDark),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = name.firstOrNull()?.uppercaseChar()?.toString() ?: "U",
                        color = Color.White,
                        fontWeight = FontWeight.Bold,
                        fontSize = 16.sp,
                    )
                }
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(
                        text = "Good morning",
                        fontSize = 13.sp,
                        color = Ink500,
                    )
                    Text(
                        text = subtitle?.let { "$name · $it" } ?: name,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold,
                        color = Ink900,
                    )
                }
            }
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(Surface50)
                    .clickable(onClick = onOpenNotifications),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.Filled.Notifications,
                    contentDescription = "Notifications",
                    tint = Ink700,
                )
                if (hasUnread) {
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .clip(CircleShape)
                            .background(MaterialTheme.colorScheme.error)
                            .border(2.dp, Surface0, CircleShape),
                    )
                }
            }
        }
    }
}

/**
 * KYC warning banner shown on engineer-home when verification is pending.
 * Tap navigates to KYC.
 */
@Composable
internal fun KycBanner(onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg, vertical = Spacing.sm)
            .clip(RoundedCornerShape(12.dp))
            .background(WarningBg)
            .border(1.dp, Color(0xFFF2D9A8), RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = Icons.Outlined.VerifiedUser,
            contentDescription = null,
            tint = Warning,
        )
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                text = "Complete KYC to accept jobs",
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
                color = Ink900,
            )
            Text(
                text = "Takes 3 mins — Aadhaar, PAN, trade cert.",
                fontSize = 12.sp,
                color = Ink700,
            )
        }
        Icon(
            imageVector = Icons.Filled.ChevronRight,
            contentDescription = null,
            tint = Ink700,
        )
    }
}

/**
 * Verified pill shown when the engineer's KYC has been approved.
 */
@Composable
internal fun KycVerifiedPill() {
    Row(
        modifier = Modifier
            .padding(horizontal = Spacing.lg, vertical = Spacing.sm)
            .clip(RoundedCornerShape(999.dp))
            .background(SuccessBg)
            .padding(horizontal = 10.dp, vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = Icons.Filled.CheckCircle,
            contentDescription = null,
            tint = Success,
            modifier = Modifier.size(16.dp),
        )
        Text(
            text = "KYC verified",
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
            color = Success,
        )
    }
}

/**
 * Big gradient hero card. Used by EngineerHome ("Available jobs nearby")
 * and other persona dashboards as the primary call-to-action surface.
 */
@Composable
internal fun GradientHero(
    eyebrow: String,
    bigValue: String,
    valueSuffix: String? = null,
    body: String,
    cta: String,
    onClick: () -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg, vertical = Spacing.sm)
            .clip(RoundedCornerShape(20.dp))
            .background(
                Brush.linearGradient(listOf(BrandGreen, BrandGreenDark)),
            )
            .clickable(onClick = onClick)
            .padding(20.dp),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                text = eyebrow,
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
                color = Color.White.copy(alpha = 0.9f),
            )
            Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = bigValue,
                    fontSize = 56.sp,
                    fontWeight = FontWeight.Light,
                    color = Color.White,
                )
                valueSuffix?.let {
                    Text(
                        text = it,
                        fontSize = 14.sp,
                        color = Color.White.copy(alpha = 0.9f),
                        modifier = Modifier.padding(bottom = 12.dp),
                    )
                }
            }
            Text(
                text = body,
                fontSize = 13.sp,
                color = Color.White.copy(alpha = 0.85f),
                modifier = Modifier.padding(top = 6.dp),
            )
            Row(
                modifier = Modifier
                    .padding(top = 12.dp)
                    .clip(RoundedCornerShape(999.dp))
                    .background(Color.White.copy(alpha = 0.18f))
                    .padding(horizontal = 14.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = cta,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White,
                )
                Icon(
                    imageVector = Icons.Filled.ArrowForward,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(16.dp),
                )
            }
        }
    }
}

/**
 * White hero card with brand-tinted icon tile + title + subline + chevron.
 * Used for primary CTAs that don't need the gradient drama (e.g. Hospital
 * "Raise a repair request" card).
 */
@Composable
internal fun PrimaryCallout(
    icon: ImageVector,
    title: String,
    subtitle: String,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg, vertical = Spacing.sm)
            .clip(RoundedCornerShape(20.dp))
            .background(Surface0)
            .border(1.dp, Surface200, RoundedCornerShape(20.dp))
            .clickable(onClick = onClick)
            .padding(20.dp),
        horizontalArrangement = Arrangement.spacedBy(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(56.dp)
                .clip(RoundedCornerShape(16.dp))
                .background(BrandGreen),
            contentAlignment = Alignment.Center,
        ) {
            Icon(imageVector = icon, contentDescription = null, tint = Color.White)
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(text = title, fontSize = 16.sp, fontWeight = FontWeight.Bold, color = Ink900)
            Text(
                text = subtitle,
                fontSize = 13.sp,
                color = Ink500,
                modifier = Modifier.padding(top = 2.dp),
            )
        }
        Icon(imageVector = Icons.Filled.ArrowForward, contentDescription = null, tint = BrandGreen)
    }
}

/**
 * Three-up stat row shown under the hero on every role dashboard. Each tile
 * is white, bordered, with a hue-tinted icon swatch + value + label.
 */
@Composable
internal fun StatRow(
    tiles: List<StatTile>,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg, vertical = Spacing.xs),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        tiles.forEach { tile ->
            StatTileCard(
                tile = tile,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

internal data class StatTile(
    val icon: ImageVector,
    val value: String,
    val label: String,
    val hue: Int,
    val onClick: () -> Unit,
)

@Composable
private fun StatTileCard(tile: StatTile, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(14.dp))
            .background(Surface0)
            .border(1.dp, Surface200, RoundedCornerShape(14.dp))
            .clickable(onClick = tile.onClick)
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Box(
            modifier = Modifier
                .size(36.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(hueToBg(tile.hue)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = tile.icon,
                contentDescription = null,
                tint = hueToFg(tile.hue),
                modifier = Modifier.size(18.dp),
            )
        }
        Text(
            text = tile.value,
            fontSize = 18.sp,
            fontWeight = FontWeight.Bold,
            color = Ink900,
        )
        Text(
            text = tile.label,
            fontSize = 11.sp,
            color = Ink500,
            fontWeight = FontWeight.Medium,
        )
    }
}

/**
 * Approximate the design's `oklch(0.94 0.04 ${hue})` background swatch /
 * `oklch(0.4 0.1 ${hue})` foreground in sRGB. Hue values match the design:
 *   150 = green tint, 40 = amber, 200 = blue, 280 = violet, 330 = pink, 0 = red.
 */
internal fun hueToBg(hue: Int): Color = when (hue) {
    in 130..170 -> BrandGreen50
    in 30..60 -> Color(0xFFFFF1D6)
    in 180..220 -> Color(0xFFE0EAF8)
    in 260..300 -> Color(0xFFEDE3F4)
    in 320..360, in 0..15 -> Color(0xFFFADCE3)
    else -> Surface50
}

internal fun hueToFg(hue: Int): Color = when (hue) {
    in 130..170 -> BrandGreenDark
    in 30..60 -> Color(0xFF8C5A0B)
    in 180..220 -> Color(0xFF21518F)
    in 260..300 -> Color(0xFF6A3596)
    in 320..360, in 0..15 -> Color(0xFFB7234B)
    else -> Ink700
}

/**
 * Section header with optional "View all" affordance on the right.
 */
@Composable
internal fun DashboardSectionHeader(
    title: String,
    actionLabel: String? = null,
    onAction: () -> Unit = {},
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg, vertical = Spacing.sm),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = title,
            fontSize = 14.sp,
            fontWeight = FontWeight.Bold,
            color = Ink900,
        )
        if (actionLabel != null) {
            Text(
                text = actionLabel,
                fontSize = 13.sp,
                color = BrandGreen,
                fontWeight = FontWeight.Medium,
                modifier = Modifier.clickable(onClick = onAction),
            )
        }
    }
}

/**
 * Generic activity / list card with leading hue tile + title + subline +
 * trailing chevron. Reused by hospital active-requests, engineer schedule,
 * supplier orders preview, etc.
 */
@Composable
internal fun ListCard(
    leadingIcon: ImageVector,
    leadingHue: Int,
    title: String,
    subtitle: String,
    trailing: String? = null,
    onClick: () -> Unit = {},
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg, vertical = 4.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(Surface0)
            .border(1.dp, Surface200, RoundedCornerShape(14.dp))
            .clickable(onClick = onClick)
            .padding(14.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(48.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(hueToBg(leadingHue)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = leadingIcon,
                contentDescription = null,
                tint = hueToFg(leadingHue),
            )
        }
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(text = title, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = Ink900)
            Text(text = subtitle, fontSize = 12.sp, color = Ink500)
        }
        if (trailing != null) {
            Text(text = trailing, fontSize = 11.sp, color = Ink500)
        } else {
            Icon(
                imageVector = Icons.Filled.ChevronRight,
                contentDescription = null,
                tint = Ink500,
            )
        }
    }
}

/**
 * Tip / informational card with brand-tinted icon, title, body, and an
 * "expand" chevron. Used by Engineer "Tip of the day" and similar.
 */
@Composable
internal fun TipCard(
    icon: ImageVector,
    title: String,
    body: String,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg, vertical = Spacing.sm)
            .clip(RoundedCornerShape(14.dp))
            .background(BrandGreen50)
            .padding(14.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = BrandGreenDark,
            modifier = Modifier.size(28.dp),
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(text = title, fontSize = 13.sp, fontWeight = FontWeight.Bold, color = Ink900)
            Text(
                text = body,
                fontSize = 13.sp,
                color = Ink700,
                modifier = Modifier.padding(top = 2.dp),
            )
        }
    }
}

/** Spacer fixed to spacing token; used so dashboards have predictable rhythm. */
@Composable
internal fun DashboardSpacer(height: androidx.compose.ui.unit.Dp = Spacing.sm) {
    Box(modifier = Modifier.height(height).width(1.dp))
}
