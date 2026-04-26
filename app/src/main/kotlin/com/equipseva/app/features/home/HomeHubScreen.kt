package com.equipseva.app.features.home

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AdminPanelSettings
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.Engineering
import androidx.compose.material.icons.filled.Storefront
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.R
import com.equipseva.app.designsystem.theme.AccentLime
import com.equipseva.app.designsystem.theme.AccentLimeSoft
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreenDeep
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.designsystem.theme.Surface50

/**
 * The new 3-card landing on the Home tab. Replaces the old role-dispatched
 * HomeScreen for v1. Three actions:
 *   - Marketplace: Buy / Sell equipment + spare parts
 *   - Book Repair: hospital raises a service request
 *   - Engineer Jobs: engineer takes jobs from the feed
 *
 * The Founder admin tile is the optional fourth tile, only rendered when
 * the signed-in user is the pinned founder. It mirrors the previous
 * Profile → Founder dashboard entry-point now that the Hub is gone.
 */
@Composable
fun HomeHubScreen(
    onOpenMarketplace: () -> Unit,
    onOpenBookRepair: () -> Unit,
    onOpenEngineerJobs: () -> Unit,
    onOpenFounder: () -> Unit = {},
    viewModel: HomeHubViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    Surface(modifier = Modifier.fillMaxSize(), color = Surface50) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState()),
        ) {
            HubHero(displayName = state.displayName)
            Spacer(Modifier.height(Spacing.lg))
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = Spacing.lg),
                verticalArrangement = Arrangement.spacedBy(Spacing.md),
            ) {
                HubTile(
                    title = "Marketplace",
                    tagline = "Buy / Sell equipment + spare parts",
                    icon = Icons.Filled.Storefront,
                    onClick = onOpenMarketplace,
                )
                HubTile(
                    title = "Book Repair",
                    tagline = "Raise a service request — engineer comes to you",
                    icon = Icons.Filled.Build,
                    onClick = onOpenBookRepair,
                )
                HubTile(
                    title = "Engineer Jobs",
                    tagline = "Pick up jobs, bid + earn (engineer login)",
                    icon = Icons.Filled.Engineering,
                    onClick = onOpenEngineerJobs,
                )
                if (state.isFounder) {
                    HubTile(
                        title = "Admin Dashboard",
                        tagline = "KYC queues, payments, integrity, categories",
                        icon = Icons.Filled.AdminPanelSettings,
                        onClick = onOpenFounder,
                        admin = true,
                    )
                }
            }
            Spacer(Modifier.height(Spacing.xl))
        }
    }
}

@Composable
private fun HubHero(displayName: String?) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(Brush.verticalGradient(listOf(BrandGreen, BrandGreenDeep)))
            .padding(horizontal = Spacing.lg, vertical = 22.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            Image(
                painter = painterResource(id = R.drawable.ic_logo_full),
                contentDescription = "EquipSeva",
                modifier = Modifier
                    .size(56.dp)
                    .clip(RoundedCornerShape(14.dp)),
            )
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = if (displayName.isNullOrBlank()) "Welcome to EquipSeva"
                           else "Hi, ${displayName.split(" ").firstOrNull() ?: displayName}",
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White,
                )
                Text(
                    text = "What would you like to do today?",
                    fontSize = 12.sp,
                    color = Color.White.copy(alpha = 0.85f),
                )
            }
        }
    }
}

@Composable
private fun HubTile(
    title: String,
    tagline: String,
    icon: ImageVector,
    onClick: () -> Unit,
    admin: Boolean = false,
) {
    val borderColor = if (admin) AccentLime else Surface200
    val borderWidth = if (admin) 1.5.dp else 1.dp
    val iconBg = if (admin) BrandGreenDeep else AccentLimeSoft
    val iconTint = if (admin) AccentLime else BrandGreen
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(Surface0)
            .border(borderWidth, borderColor, RoundedCornerShape(18.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 18.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Box(
            modifier = Modifier
                .size(60.dp)
                .clip(RoundedCornerShape(16.dp))
                .background(iconBg),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = iconTint,
                modifier = Modifier.size(32.dp),
            )
        }
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                text = title,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = Ink900,
            )
            Text(
                text = tagline,
                fontSize = 12.sp,
                lineHeight = 16.sp,
                color = Ink500,
            )
        }
        Text(
            "›",
            fontSize = 26.sp,
            color = Ink500,
        )
    }
}
