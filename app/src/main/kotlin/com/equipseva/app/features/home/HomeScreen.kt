package com.equipseva.app.features.home

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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Assignment
import androidx.compose.material.icons.automirrored.filled.TrendingUp
import androidx.compose.material.icons.filled.Analytics
import androidx.compose.material.icons.filled.ArrowForward
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.DocumentScanner
import androidx.compose.material.icons.filled.Engineering
import androidx.compose.material.icons.filled.Gavel
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Inventory
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Paid
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material.icons.filled.ShoppingCart
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Store
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.filled.Work
import androidx.compose.material.icons.outlined.Badge
import androidx.compose.material.icons.outlined.RequestQuote
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.designsystem.components.ActivityFeedRow
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.GradientTile
import com.equipseva.app.designsystem.components.SectionHeader
import com.equipseva.app.designsystem.components.StatusBanner
import com.equipseva.app.designsystem.components.StatusBannerTone
import com.equipseva.app.designsystem.components.StatusChip
import com.equipseva.app.designsystem.components.StatusTone
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreen50
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.ErrorRed
import com.equipseva.app.designsystem.theme.Ink400
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Outline
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface50
import com.equipseva.app.features.auth.UserRole

@Composable
fun HomeScreen(
    onShowMessage: (String) -> Unit,
    onCardClick: (String) -> Unit = {},
    viewModel: HomeViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(viewModel) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is HomeViewModel.Effect.ShowMessage -> onShowMessage(effect.text)
            }
        }
    }

    // Custom header replaces the generic ESTopBar — each persona renders its own
    // greeting + bell row inside HomeContent.
    Scaffold(containerColor = Surface50) { inner ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(inner),
        ) {
            when {
                state.loading -> {
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = BrandGreen)
                    }
                }
                state.errorMessage != null -> {
                    HomeErrorView(
                        message = state.errorMessage!!,
                        onRetry = viewModel::onRetry,
                    )
                }
                else -> {
                    HomeContent(
                        greetingName = state.greetingName,
                        role = state.role,
                        onCardClick = onCardClick,
                    )
                }
            }
        }
    }
}

@Composable
private fun HomeContent(
    greetingName: String,
    role: UserRole?,
    onCardClick: (String) -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
    ) {
        when (role) {
            UserRole.ENGINEER -> EngineerHome(greetingName, onCardClick)
            UserRole.HOSPITAL -> HospitalHome(greetingName, onCardClick)
            UserRole.SUPPLIER,
            UserRole.MANUFACTURER,
            UserRole.LOGISTICS,
            -> GenericPersonaHome(greetingName, role, onCardClick)
            null -> NoRoleHome(greetingName)
        }
    }
}

// ----- Header (shared) ----------------------------------------------------

@Composable
private fun HomeHeader(
    greetingName: String,
    subtitle: String,
    accentColor: Color = BrandGreen,
    hasUnread: Boolean = true,
    onBellClick: () -> Unit = {},
) {
    Surface(
        color = Surface0,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(
            modifier = Modifier.padding(
                start = Spacing.lg,
                end = Spacing.sm,
                top = Spacing.sm,
                bottom = Spacing.lg,
            ),
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
                ) {
                    InitialsAvatar(name = greetingName, color = accentColor, size = 40.dp)
                    Column {
                        Text(
                            text = "Good morning",
                            style = MaterialTheme.typography.labelMedium,
                            color = Ink500,
                        )
                        Text(
                            text = greetingName,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold,
                            color = Ink900,
                        )
                        if (subtitle.isNotBlank()) {
                            Text(
                                text = subtitle,
                                style = MaterialTheme.typography.labelSmall,
                                color = Ink500,
                            )
                        }
                    }
                }
                NotificationBell(hasUnread = hasUnread, onClick = onBellClick)
            }
        }
    }
}

@Composable
private fun InitialsAvatar(name: String, color: Color, size: androidx.compose.ui.unit.Dp) {
    val initials = remember(name) {
        name.trim()
            .split(Regex("\\s+"))
            .filter { it.isNotEmpty() }
            .take(2)
            .joinToString("") { it.first().uppercase() }
            .ifBlank { "?" }
    }
    Box(
        modifier = Modifier
            .size(size)
            .clip(CircleShape)
            .background(color),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = initials,
            color = Color.White,
            fontWeight = FontWeight.SemiBold,
            fontSize = 14.sp,
        )
    }
}

@Composable
private fun NotificationBell(hasUnread: Boolean, onClick: () -> Unit) {
    Box {
        IconButton(
            onClick = onClick,
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(Surface50),
        ) {
            Icon(
                imageVector = Icons.Filled.Notifications,
                contentDescription = "Notifications",
                tint = Ink700,
            )
        }
        if (hasUnread) {
            Box(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(top = 8.dp, end = 8.dp)
                    .size(8.dp)
                    .border(2.dp, Surface0, CircleShape)
                    .clip(CircleShape)
                    .background(ErrorRed),
            )
        }
    }
}

// ----- Engineer Home ------------------------------------------------------

@Composable
private fun EngineerHome(greetingName: String, onCardClick: (String) -> Unit) {
    val verified = false // No KYC state on UiState — show the prompt by default.
    Column(modifier = Modifier.fillMaxWidth()) {
        Surface(color = Surface0) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = Spacing.lg, end = Spacing.lg, top = Spacing.sm, bottom = Spacing.lg),
                verticalArrangement = Arrangement.spacedBy(Spacing.md),
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
                    ) {
                        InitialsAvatar(name = greetingName, color = BrandGreen, size = 40.dp)
                        Column {
                            Text(
                                text = "Good morning",
                                style = MaterialTheme.typography.labelMedium,
                                color = Ink500,
                            )
                            Text(
                                text = greetingName,
                                fontSize = 16.sp,
                                fontWeight = FontWeight.Bold,
                                color = Ink900,
                            )
                            Text(
                                text = "Engineer · Bengaluru",
                                style = MaterialTheme.typography.labelSmall,
                                color = Ink500,
                            )
                        }
                    }
                    NotificationBell(hasUnread = true, onClick = {})
                }
                if (!verified) {
                    StatusBanner(
                        title = "Verify your KYC to unlock hospital bids",
                        message = "Takes 3 mins — Aadhaar, PAN, trade cert.",
                        tone = StatusBannerTone.Warn,
                        leadingIcon = Icons.Filled.Shield,
                        action = {
                            VerifyChip(onClick = { onCardClick("kyc") })
                        },
                    )
                } else {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(Spacing.xs),
                        modifier = Modifier
                            .clip(RoundedCornerShape(50))
                            .background(MaterialTheme.colorScheme.primaryContainer)
                            .padding(horizontal = Spacing.sm, vertical = 6.dp),
                    ) {
                        Icon(
                            imageVector = Icons.Filled.Verified,
                            contentDescription = null,
                            tint = BrandGreen,
                            modifier = Modifier.size(14.dp),
                        )
                        Text(
                            text = "KYC verified",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold,
                            color = BrandGreen,
                        )
                    }
                }
            }
        }

        Spacer(Modifier.height(Spacing.lg))

        // Hero gradient card — "12 jobs within 10 km"
        Box(modifier = Modifier.padding(horizontal = Spacing.lg)) {
            EngineerHeroCard(
                count = 12,
                onClick = { onCardClick("jobs_nearby") },
            )
        }

        Spacer(Modifier.height(Spacing.md))

        // Three-tile grid
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = Spacing.lg),
            horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            EngineerStatTile(
                modifier = Modifier.weight(1f),
                icon = Icons.Filled.Engineering,
                count = "3",
                label = "Active work",
                hue = 150,
                onClick = { onCardClick("active_work") },
            )
            EngineerStatTile(
                modifier = Modifier.weight(1f),
                icon = Icons.Filled.Gavel,
                count = "7",
                label = "My bids",
                hue = 40,
                onClick = { onCardClick("my_bids") },
            )
            EngineerStatTile(
                modifier = Modifier.weight(1f),
                icon = Icons.Filled.Paid,
                count = "₹24.5k",
                label = "Earnings",
                hue = 200,
                onClick = { onCardClick("earnings") },
            )
        }

        SectionHeader(title = "Today's schedule")
        Column(
            modifier = Modifier.padding(horizontal = Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            ScheduleRow(
                timeTop = "NOW",
                timeBottom = "11:30",
                title = "Apollo Greams · CT scanner",
                subtitle = "Tube overheating · 3.2 km away",
                statusLabel = "En route",
                statusTone = StatusTone.Info,
                isNow = true,
                onClick = { onCardClick("active_work") },
            )
            ScheduleRow(
                timeTop = "3:00",
                timeBottom = "PM",
                title = "MIOT · ECG repair",
                subtitle = "Cable damage · 5.1 km away",
                statusLabel = "Accepted",
                statusTone = StatusTone.Success,
                isNow = false,
                onClick = { onCardClick("active_work") },
            )
        }

        SectionHeader(title = "Quick actions")
        Column(
            modifier = Modifier.padding(horizontal = Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            cardsFor(UserRole.ENGINEER).forEach { entry ->
                HomeActionCard(
                    icon = entry.icon,
                    title = entry.title,
                    subtitle = entry.subtitle,
                    hue = entry.hue,
                    onClick = { onCardClick(entry.key) },
                )
            }
        }

        Spacer(Modifier.height(Spacing.xl))
    }
}

@Composable
private fun VerifyChip(onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(BrandGreen)
            .clickable(onClick = onClick)
            .padding(horizontal = Spacing.md, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(
            text = "Verify",
            color = Color.White,
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
        )
        Icon(
            imageVector = Icons.Filled.ChevronRight,
            contentDescription = null,
            tint = Color.White,
            modifier = Modifier.size(14.dp),
        )
    }
}

@Composable
private fun EngineerHeroCard(count: Int, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(
                Brush.linearGradient(
                    colors = listOf(BrandGreen, BrandGreenDark),
                    start = Offset(0f, 0f),
                    end = Offset(Float.POSITIVE_INFINITY, Float.POSITIVE_INFINITY),
                ),
            )
            .drawBehind {
                drawCircle(
                    color = Color.White.copy(alpha = 0.08f),
                    radius = 90.dp.toPx(),
                    center = Offset(size.width + 30.dp.toPx(), -30.dp.toPx()),
                )
                drawCircle(
                    color = Color.White.copy(alpha = 0.05f),
                    radius = 60.dp.toPx(),
                    center = Offset(size.width - 80.dp.toPx(), size.height + 40.dp.toPx()),
                )
            }
            .clickable(onClick = onClick)
            .padding(20.dp),
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            Text(
                text = "Available jobs nearby",
                style = MaterialTheme.typography.labelMedium,
                color = Color.White.copy(alpha = 0.9f),
                fontWeight = FontWeight.Medium,
            )
            Spacer(Modifier.height(4.dp))
            Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                Text(
                    text = count.toString(),
                    fontSize = 56.sp,
                    lineHeight = 56.sp,
                    fontWeight = FontWeight.Normal,
                    color = Color.White,
                    letterSpacing = (-2).sp,
                )
                Text(
                    text = "within 10 km",
                    style = MaterialTheme.typography.bodyMedium,
                    color = Color.White.copy(alpha = 0.9f),
                    modifier = Modifier.padding(bottom = 8.dp),
                )
            }
            Spacer(Modifier.height(10.dp))
            Text(
                text = "Tap to view feed, place bids, and earn.",
                style = MaterialTheme.typography.bodyMedium,
                color = Color.White.copy(alpha = 0.85f),
            )
            Spacer(Modifier.height(Spacing.lg))
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .background(Color.White.copy(alpha = 0.18f))
                    .padding(horizontal = Spacing.md, vertical = 8.dp),
            ) {
                Text(
                    text = "View feed",
                    color = Color.White,
                    fontWeight = FontWeight.Bold,
                    fontSize = 13.sp,
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

@Composable
private fun EngineerStatTile(
    icon: ImageVector,
    count: String,
    label: String,
    hue: Int,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val bg = Color.hsl(hue.toFloat().coerceIn(0f, 360f), saturation = 0.22f, lightness = 0.94f)
    val fg = Color.hsl(hue.toFloat().coerceIn(0f, 360f), saturation = 0.35f, lightness = 0.42f)
    Card(
        colors = CardDefaults.cardColors(containerColor = Surface0),
        shape = RoundedCornerShape(14.dp),
        border = androidx.compose.foundation.BorderStroke(1.dp, Outline),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
        modifier = modifier.clickable(onClick = onClick),
    ) {
        Column(
            modifier = Modifier.padding(Spacing.md),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(bg),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = fg,
                    modifier = Modifier.size(18.dp),
                )
            }
            Text(
                text = count,
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                color = Ink900,
                letterSpacing = (-0.3).sp,
            )
            Text(
                text = label,
                style = MaterialTheme.typography.labelMedium,
                color = Ink500,
                fontWeight = FontWeight.Medium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

@Composable
private fun ScheduleRow(
    timeTop: String,
    timeBottom: String,
    title: String,
    subtitle: String,
    statusLabel: String,
    statusTone: StatusTone,
    isNow: Boolean,
    onClick: () -> Unit,
) {
    Card(
        colors = CardDefaults.cardColors(containerColor = Surface0),
        border = androidx.compose.foundation.BorderStroke(1.dp, Outline),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(Spacing.md),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            Column(
                modifier = Modifier
                    .size(width = 52.dp, height = 52.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(if (isNow) BrandGreen50 else Color.Transparent)
                    .padding(vertical = 6.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                Text(
                    text = timeTop,
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 0.4.sp,
                    color = if (isNow) BrandGreenDark else Ink500,
                )
                Text(
                    text = timeBottom,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = if (isNow) BrandGreenDark else Ink900,
                )
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleSmall,
                    color = Ink900,
                    fontWeight = FontWeight.Bold,
                )
                Spacer(Modifier.height(2.dp))
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = Ink500,
                )
            }
            StatusChip(label = statusLabel, tone = statusTone)
        }
    }
}

// ----- Hospital Home ------------------------------------------------------

@Composable
private fun HospitalHome(greetingName: String, onCardClick: (String) -> Unit) {
    Column(modifier = Modifier.fillMaxWidth()) {
        HomeHeader(
            greetingName = greetingName,
            subtitle = "Hospital",
        )
        Spacer(Modifier.height(Spacing.lg))

        // Primary CTA — raise repair request
        Box(modifier = Modifier.padding(horizontal = Spacing.lg)) {
            HospitalPrimaryCta(onClick = { onCardClick("request_service") })
        }

        Spacer(Modifier.height(Spacing.md))

        // Stats row (horizontal layout per tile)
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = Spacing.lg),
            horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            HospitalStatTile(
                modifier = Modifier.weight(1f),
                icon = Icons.Filled.Build,
                count = "4",
                label = "Active",
                hue = 150,
                onClick = { onCardClick("active_jobs") },
            )
            HospitalStatTile(
                modifier = Modifier.weight(1f),
                icon = Icons.Filled.LocalShipping,
                count = "2",
                label = "Orders",
                hue = 40,
                onClick = { onCardClick("order_history") },
            )
            HospitalStatTile(
                modifier = Modifier.weight(1f),
                icon = Icons.Filled.History,
                count = "7",
                label = "Reorder",
                hue = 200,
                onClick = { onCardClick("browse_parts") },
            )
        }

        SectionHeader(
            title = "Active requests",
            actionLabel = "View all",
            onAction = { onCardClick("active_jobs") },
        )
        Column(
            modifier = Modifier.padding(horizontal = Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            HospitalRequestCard(
                title = "MRI 1.5T · GE Signa",
                subtitle = "Gradient coil issue · Radiology Wing",
                statusLabel = "Bid placed",
                statusTone = StatusTone.Info,
                bidsLabel = "4 bids",
                hue = 150,
                icon = Icons.Filled.Build,
                onClick = { onCardClick("active_jobs") },
            )
            HospitalRequestCard(
                title = "ECG · Philips PageWriter TC70",
                subtitle = "Cable damage · Ward 3B",
                statusLabel = "En route",
                statusTone = StatusTone.Warn,
                bidsLabel = null,
                hue = 40,
                icon = Icons.Filled.Build,
                onClick = { onCardClick("active_jobs") },
            )
        }

        SectionHeader(title = "Staff activity")
        Card(
            colors = CardDefaults.cardColors(containerColor = Surface0),
            border = androidx.compose.foundation.BorderStroke(1.dp, Outline),
            elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = Spacing.lg),
        ) {
            Column {
                ActivityFeedRow(
                    icon = Icons.Filled.Gavel,
                    name = "Dr. Kumar",
                    action = "approved bid from Ravi K.",
                    time = "14m",
                )
                Divider()
                ActivityFeedRow(
                    icon = Icons.Filled.ShoppingCart,
                    name = "Nurse Asha",
                    action = "ordered 40× ECG electrodes",
                    time = "2h",
                )
                Divider()
                ActivityFeedRow(
                    icon = Icons.Filled.Star,
                    name = "Biomed. Sanjay",
                    action = "rated engineer 5★",
                    time = "1d",
                )
            }
        }

        SectionHeader(title = "Quick actions")
        Column(
            modifier = Modifier.padding(horizontal = Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            cardsFor(UserRole.HOSPITAL).forEach { entry ->
                HomeActionCard(
                    icon = entry.icon,
                    title = entry.title,
                    subtitle = entry.subtitle,
                    hue = entry.hue,
                    onClick = { onCardClick(entry.key) },
                )
            }
        }
        Spacer(Modifier.height(Spacing.xl))
    }
}

@Composable
private fun Divider() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(1.dp)
            .background(Outline),
    )
}

@Composable
private fun HospitalPrimaryCta(onClick: () -> Unit) {
    Card(
        colors = CardDefaults.cardColors(containerColor = Surface0),
        shape = RoundedCornerShape(20.dp),
        border = androidx.compose.foundation.BorderStroke(1.dp, Outline),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(56.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(BrandGreen),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.Filled.Build,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(28.dp),
                )
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "Raise a repair request",
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = Ink900,
                )
                Spacer(Modifier.height(2.dp))
                Text(
                    text = "Get bids from verified engineers.",
                    style = MaterialTheme.typography.bodySmall,
                    color = Ink500,
                )
            }
            Icon(
                imageVector = Icons.Filled.ArrowForward,
                contentDescription = null,
                tint = BrandGreen,
            )
        }
    }
}

@Composable
private fun HospitalStatTile(
    icon: ImageVector,
    count: String,
    label: String,
    hue: Int,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val bg = Color.hsl(hue.toFloat().coerceIn(0f, 360f), saturation = 0.22f, lightness = 0.94f)
    val fg = Color.hsl(hue.toFloat().coerceIn(0f, 360f), saturation = 0.35f, lightness = 0.42f)
    Card(
        colors = CardDefaults.cardColors(containerColor = Surface0),
        shape = RoundedCornerShape(12.dp),
        border = androidx.compose.foundation.BorderStroke(1.dp, Outline),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
        modifier = modifier.clickable(onClick = onClick),
    ) {
        Row(
            modifier = Modifier.padding(Spacing.md),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(34.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(bg),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = fg,
                    modifier = Modifier.size(18.dp),
                )
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = count,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = Ink900,
                    letterSpacing = (-0.3).sp,
                    maxLines = 1,
                )
                Spacer(Modifier.height(2.dp))
                Text(
                    text = label,
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Medium,
                    color = Ink500,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

@Composable
private fun HospitalRequestCard(
    title: String,
    subtitle: String,
    statusLabel: String,
    statusTone: StatusTone,
    bidsLabel: String?,
    hue: Int,
    icon: ImageVector,
    onClick: () -> Unit,
) {
    Card(
        colors = CardDefaults.cardColors(containerColor = Surface0),
        border = androidx.compose.foundation.BorderStroke(1.dp, Outline),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(Spacing.md),
            verticalAlignment = Alignment.Top,
            horizontalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            GradientTile(icon = icon, hue = hue, size = 48.dp)
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleSmall,
                    color = Ink900,
                    fontWeight = FontWeight.Bold,
                )
                Spacer(Modifier.height(2.dp))
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = Ink500,
                )
                Spacer(Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    StatusChip(label = statusLabel, tone = statusTone)
                    if (bidsLabel != null) {
                        StatusChip(label = bidsLabel, tone = StatusTone.Neutral)
                    }
                }
            }
        }
    }
}

// ----- Generic persona (Supplier / Manufacturer / Logistics) --------------

@Composable
private fun GenericPersonaHome(
    greetingName: String,
    role: UserRole,
    onCardClick: (String) -> Unit,
) {
    HomeHeader(
        greetingName = greetingName,
        subtitle = role.displayName,
    )
    Spacer(Modifier.height(Spacing.md))
    Column(
        modifier = Modifier.padding(horizontal = Spacing.lg),
        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        Text(
            text = "Welcome back, $greetingName",
            style = MaterialTheme.typography.headlineSmall,
            color = Ink900,
            fontWeight = FontWeight.SemiBold,
        )
        Text(
            text = role.displayName,
            style = MaterialTheme.typography.bodyMedium,
            color = Ink500,
        )
    }
    SectionHeader(title = "Quick actions")
    Column(
        modifier = Modifier.padding(horizontal = Spacing.lg),
        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        cardsFor(role).forEach { entry ->
            HomeActionCard(
                icon = entry.icon,
                title = entry.title,
                subtitle = entry.subtitle,
                hue = entry.hue,
                onClick = { onCardClick(entry.key) },
            )
        }
    }
    Spacer(Modifier.height(Spacing.xl))
}

// ----- No role selected ---------------------------------------------------

@Composable
private fun NoRoleHome(greetingName: String) {
    HomeHeader(greetingName = greetingName, subtitle = "")
    Spacer(Modifier.height(Spacing.lg))
    Box(modifier = Modifier.padding(Spacing.lg)) {
        EmptyStateView(
            icon = Icons.Outlined.Badge,
            title = "No role selected",
            subtitle = "Choose a role in Profile to see personalised actions.",
        )
    }
}

// ----- Shared list card ---------------------------------------------------

@Composable
private fun HomeActionCard(
    icon: ImageVector,
    title: String,
    subtitle: String,
    hue: Int,
    onClick: () -> Unit,
) {
    Card(
        colors = CardDefaults.cardColors(containerColor = Surface0),
        border = androidx.compose.foundation.BorderStroke(1.dp, Outline),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(Spacing.md),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            GradientTile(icon = icon, hue = hue, size = 44.dp)
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(Spacing.xxs),
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = Ink900,
                )
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = Ink500,
                )
            }
            Icon(
                imageVector = Icons.Filled.ChevronRight,
                contentDescription = null,
                tint = Ink400,
            )
        }
    }
}

// ----- Quick-action data --------------------------------------------------

private data class HomeCardEntry(
    val key: String,
    val icon: ImageVector,
    val title: String,
    val subtitle: String,
    val hue: Int,
)

private fun cardsFor(role: UserRole?): List<HomeCardEntry> = when (role) {
    UserRole.HOSPITAL -> listOf(
        HomeCardEntry("scan_equipment", Icons.Filled.DocumentScanner, "Scan equipment", "Identify equipment with AI and find matching parts", hue = 260),
        HomeCardEntry("browse_parts", Icons.Filled.Search, "Browse parts", "Find compatible parts for your equipment", hue = 200),
        HomeCardEntry("active_jobs", Icons.Filled.Build, "Active repair jobs", "Track ongoing repairs", hue = 150),
        HomeCardEntry("order_history", Icons.Filled.History, "Order history", "Review past purchases and invoices", hue = 40),
        HomeCardEntry("request_service", Icons.AutoMirrored.Filled.Assignment, "Request a service", "Post a new repair request", hue = 280),
        HomeCardEntry("hospital_create_rfq", Icons.Filled.Description, "Create an RFQ", "Request quotations from suppliers", hue = 330),
        HomeCardEntry("my_rfqs", Icons.Outlined.RequestQuote, "My RFQs", "Track your open and past quotation requests", hue = 200),
    )
    UserRole.ENGINEER -> listOf(
        HomeCardEntry("scan_equipment", Icons.Filled.DocumentScanner, "Scan equipment", "Identify equipment on-site and look up parts", hue = 260),
        HomeCardEntry("jobs_nearby", Icons.Filled.LocationOn, "Open jobs near me", "Jobs posted in your area", hue = 150),
        HomeCardEntry("my_bids", Icons.Filled.Description, "My bids", "Track bids you've placed", hue = 40),
        HomeCardEntry("active_work", Icons.Filled.Work, "Active work", "Jobs you're currently on", hue = 200),
        HomeCardEntry("earnings", Icons.Filled.Paid, "Earnings summary", "Payouts and pending amounts", hue = 280),
        HomeCardEntry("engineer_profile", Icons.Outlined.Badge, "My engineer profile", "Rates, service areas, specializations", hue = 330),
    )
    UserRole.SUPPLIER -> listOf(
        HomeCardEntry("incoming_orders", Icons.Filled.ShoppingCart, "Incoming orders", "New and pending orders", hue = 150),
        HomeCardEntry("my_listings", Icons.Filled.Store, "My listings", "Manage parts you sell", hue = 200),
        HomeCardEntry("supplier_add_listing", Icons.Filled.Inventory2, "Add a listing", "Publish a new spare part", hue = 40),
        HomeCardEntry("stock_alerts", Icons.Filled.Warning, "Stock alerts", "Low or out-of-stock items", hue = 0),
        HomeCardEntry("rfqs", Icons.Filled.Description, "RFQs", "Requests for quotation", hue = 280),
    )
    UserRole.MANUFACTURER -> listOf(
        HomeCardEntry("rfqs_assigned", Icons.AutoMirrored.Filled.Assignment, "RFQs assigned", "Quotation requests for you", hue = 280),
        HomeCardEntry("lead_pipeline", Icons.AutoMirrored.Filled.TrendingUp, "Lead pipeline", "Leads in progress", hue = 200),
        HomeCardEntry("analytics", Icons.Filled.Analytics, "Analytics", "Performance and trends", hue = 150),
    )
    UserRole.LOGISTICS -> listOf(
        HomeCardEntry("pickup_queue", Icons.Filled.Inventory2, "Pickup queue", "Shipments awaiting pickup", hue = 40),
        HomeCardEntry("active_deliveries", Icons.Filled.LocalShipping, "Active deliveries", "Currently on the road", hue = 200),
        HomeCardEntry("completed_today", Icons.Filled.Inventory, "Completed today", "Deliveries closed today", hue = 150),
    )
    null -> emptyList()
}

// ----- Error state --------------------------------------------------------

@Composable
private fun HomeErrorView(
    message: String,
    onRetry: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(Spacing.lg),
        verticalArrangement = Arrangement.spacedBy(Spacing.md, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(
            imageVector = Icons.Filled.Warning,
            contentDescription = null,
            tint = ErrorRed,
            modifier = Modifier.size(48.dp),
        )
        Text(message, style = MaterialTheme.typography.bodyLarge, color = Ink900)
        com.equipseva.app.designsystem.components.PrimaryButton(
            label = "Retry",
            onClick = onRetry,
        )
    }
}
