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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Chat
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.ChatBubbleOutline
import androidx.compose.material.icons.filled.CurrencyRupee
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.WorkOutline
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
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
import com.equipseva.app.core.data.engineers.VerificationStatus
import com.equipseva.app.designsystem.components.EsSection
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaGlowRaw
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaGreen900
import com.equipseva.app.designsystem.theme.SevaInfo50
import com.equipseva.app.designsystem.theme.SevaInfo500
import com.equipseva.app.designsystem.theme.SevaInk400
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk600
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.designsystem.theme.SevaWarning50
import com.equipseva.app.designsystem.theme.SevaWarning500
import com.equipseva.app.features.auth.UserRole
import java.time.Duration
import java.time.Instant

@Composable
fun HomeHubScreen(
    onOpenBookRepair: () -> Unit,
    onOpenEngineerJobs: () -> Unit,
    onOpenFounder: () -> Unit = {},
    onOpenNotifications: () -> Unit = {},
    onOpenKyc: () -> Unit = {},
    onOpenMyBookings: () -> Unit = {},
    onOpenMessages: () -> Unit = {},
    onOpenActiveWork: () -> Unit = {},
    onOpenEarnings: () -> Unit = {},
    viewModel: HomeHubViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val role = state.role
    val kyc = state.kycStatus

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState()),
        ) {
            HomeTopBar(onNotifications = onOpenNotifications, hasUnread = state.recent.any { it.isUnread })

            // Greeting card
            Box(modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp)) {
                GreetingCard(
                    role = role,
                    displayName = state.displayName,
                    openCount = state.openCount,
                    activeCount = state.activeCount,
                    pendingBidsCount = state.pendingBidsCount,
                )
            }

            // KYC banner — engineer who isn't verified yet
            if (role == UserRole.ENGINEER && kyc != VerificationStatus.Verified) {
                Box(modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)) {
                    KycBanner(status = kyc, onClick = onOpenKyc)
                }
            }

            Spacer(Modifier.height(8.dp))

            // Tiles — role-aware per design (`screens-home.jsx:103-140`).
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                if (role == UserRole.HOSPITAL) {
                    HomeTile(
                        icon = Icons.Filled.Bolt,
                        title = "Book a repair engineer",
                        desc = "Browse verified biomedical engineers near you",
                        onClick = onOpenBookRepair,
                    )
                    HomeTile(
                        icon = Icons.Outlined.WorkOutline,
                        title = "My bookings",
                        desc = "Track open and active repair jobs",
                        onClick = onOpenMyBookings,
                    )
                    HomeTile(
                        icon = Icons.AutoMirrored.Outlined.Chat,
                        title = "Messages",
                        desc = "Chat with engineers",
                        onClick = onOpenMessages,
                    )
                } else {
                    val engVerified = kyc == VerificationStatus.Verified
                    HomeTile(
                        icon = Icons.Filled.Build,
                        title = "Today's jobs",
                        desc = if (engVerified) "New requests near you" else "Browse open repair jobs",
                        onClick = onOpenEngineerJobs,
                    )
                    HomeTile(
                        icon = Icons.Outlined.WorkOutline,
                        title = "Active work",
                        desc = "Jobs in progress",
                        onClick = onOpenActiveWork,
                    )
                    HomeTile(
                        icon = Icons.Filled.CurrencyRupee,
                        title = "Earnings",
                        desc = "This month, payouts, tax docs",
                        onClick = onOpenEarnings,
                    )
                }
                if (state.isFounder) {
                    HomeTile(
                        icon = Icons.Filled.Shield,
                        title = "Admin Dashboard",
                        desc = "Founder tools — KYC queue, reports, payments",
                        onClick = onOpenFounder,
                        accent = TileAccent.Admin,
                    )
                }
            }

            Spacer(Modifier.height(12.dp))

            // Recent activity
            if (state.recent.isNotEmpty()) {
                EsSection(
                    title = "Recent activity",
                    action = "See all",
                    onAction = onOpenNotifications,
                ) {
                    Column(
                        modifier = Modifier
                            .padding(horizontal = 16.dp)
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(12.dp))
                            .background(Color.White)
                            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp)),
                    ) {
                        state.recent.forEachIndexed { i, n ->
                            ActivityRow(
                                kind = n.kind,
                                title = n.title.ifBlank { n.body },
                                relativeTime = relativeTime(n.sentAt),
                                unread = n.isUnread,
                                isLast = i == state.recent.lastIndex,
                                onClick = onOpenNotifications,
                            )
                        }
                    }
                }
            }

            Spacer(Modifier.height(24.dp))
        }
    }
}

@Composable
private fun HomeTopBar(onNotifications: () -> Unit, hasUnread: Boolean) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(56.dp)
            .background(PaperDefault)
            .border(1.dp, BorderDefault, RoundedCornerShape(0.dp))
            .padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Image(
            painter = painterResource(R.drawable.ic_logo_mark),
            contentDescription = "EquipSeva",
            modifier = Modifier
                .size(32.dp)
                .clip(RoundedCornerShape(8.dp)),
        )
        Spacer(Modifier.size(10.dp))
        Text(
            text = "EquipSeva",
            style = EsType.H5,
            color = SevaInk900,
            modifier = Modifier.weight(1f),
        )
        Box(
            modifier = Modifier
                .size(36.dp)
                .clip(CircleShape)
                .clickable(onClick = onNotifications),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = Icons.Filled.Notifications,
                contentDescription = "Notifications",
                tint = SevaInk700,
                modifier = Modifier.size(20.dp),
            )
            if (hasUnread) {
                Box(
                    modifier = Modifier
                        .size(8.dp)
                        .clip(CircleShape)
                        .background(SevaDanger500)
                        .border(2.dp, Color.White, CircleShape)
                        .align(Alignment.TopEnd),
                )
            }
        }
    }
}

@Composable
private fun GreetingCard(
    role: UserRole?,
    displayName: String?,
    openCount: Int?,
    activeCount: Int?,
    pendingBidsCount: Int?,
) {
    val greeting = remember { greetingForNow() }
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(Brush.linearGradient(listOf(SevaGreen700, SevaGreen900)))
            .padding(18.dp),
    ) {
        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .size(140.dp)
                .clip(CircleShape)
                .background(SevaGlowRaw.copy(alpha = 0.08f)),
        )
        Column {
            Text(
                text = greeting,
                fontSize = 13.sp,
                color = Color.White.copy(alpha = 0.75f),
            )
            Spacer(Modifier.height(4.dp))
            Text(
                text = if (role == UserRole.ENGINEER) "Ready for work today?" else "What needs fixing today?",
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White,
            )
            Spacer(Modifier.height(14.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(20.dp)) {
                if (role == UserRole.ENGINEER) {
                    // "Nearby" is location-derived and not yet wired into this
                    // hero — left as "—" until a radius RPC stream lands.
                    Stat("Nearby", "—")
                    Stat("Pending bids", pendingBidsCount?.toString() ?: "—")
                    Stat("Active", activeCount?.toString() ?: "—")
                } else {
                    Stat("Open", openCount?.toString() ?: "—")
                    Stat("Active", activeCount?.toString() ?: "—")
                    // "Engineers" needs a directory count fetch; left as "—".
                    Stat("Engineers", "—")
                }
            }
            if (!displayName.isNullOrBlank()) {
                Spacer(Modifier.height(2.dp))
            }
        }
    }
}

@Composable
private fun Stat(label: String, value: String) {
    Column {
        Text(label, fontSize = 12.sp, color = Color.White.copy(alpha = 0.65f))
        Spacer(Modifier.height(2.dp))
        Text(value, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Color.White)
    }
}

@Composable
private fun KycBanner(status: VerificationStatus?, onClick: () -> Unit) {
    val pending = status == VerificationStatus.Pending
    val bg = if (pending) SevaInfo50 else SevaWarning50
    val tint = if (pending) SevaInfo500 else SevaWarning500
    val title = when (status) {
        VerificationStatus.Pending -> "KYC under review"
        VerificationStatus.Rejected -> "KYC needs another try"
        else -> "Become a verified repairman"
    }
    val sub = when (status) {
        VerificationStatus.Pending -> "Usually 24h. We'll notify you."
        VerificationStatus.Rejected -> "Re-submit the missing docs to enter the queue."
        else -> "Submit KYC to start bidding on jobs."
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(bg)
            .clickable(onClick = onClick)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(Icons.Filled.Shield, contentDescription = null, tint = tint, modifier = Modifier.size(20.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(title, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = SevaInk900)
            Spacer(Modifier.height(2.dp))
            Text(sub, fontSize = 11.sp, color = SevaInk600)
        }
        Icon(
            Icons.Outlined.ChevronRight,
            contentDescription = null,
            tint = SevaInk400,
            modifier = Modifier.size(16.dp),
        )
    }
}

private enum class TileAccent { Default, Admin }

@Composable
private fun HomeTile(
    icon: ImageVector,
    title: String,
    desc: String,
    onClick: () -> Unit,
    badge: String? = null,
    accent: TileAccent = TileAccent.Default,
) {
    val tileBg = when (accent) {
        TileAccent.Default -> SevaGreen50
        TileAccent.Admin -> SevaWarning50
    }
    val tileFg = when (accent) {
        TileAccent.Default -> SevaGreen700
        TileAccent.Admin -> SevaWarning500
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(14.dp))
            .clickable(onClick = onClick)
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Box(
            modifier = Modifier
                .size(48.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(tileBg),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = null, tint = tileFg, modifier = Modifier.size(24.dp))
        }
        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(title, fontSize = 15.sp, fontWeight = FontWeight.Bold, color = SevaInk900)
                if (badge != null) Pill(text = badge, kind = PillKind.Warn)
            }
            Spacer(Modifier.height(4.dp))
            Text(desc, fontSize = 12.sp, color = SevaInk500, lineHeight = 16.sp)
        }
        Icon(
            Icons.Outlined.ChevronRight,
            contentDescription = null,
            tint = SevaInk400,
            modifier = Modifier.size(18.dp),
        )
    }
}

@Composable
private fun ActivityRow(
    kind: String?,
    title: String,
    relativeTime: String,
    unread: Boolean,
    isLast: Boolean,
    onClick: () -> Unit,
) {
    val icon = when (kind) {
        "bid", "job_bid" -> Icons.Filled.CurrencyRupee
        "msg", "chat", "message" -> Icons.Filled.ChatBubbleOutline
        "kyc", "verification" -> Icons.Filled.Shield
        else -> Icons.Filled.Bolt
    }
    Column {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(onClick = onClick)
                .padding(horizontal = 14.dp, vertical = 12.dp),
            verticalAlignment = Alignment.Top,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(32.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(SevaGreen50),
                contentAlignment = Alignment.Center,
            ) {
                Icon(icon, contentDescription = null, tint = SevaGreen700, modifier = Modifier.size(16.dp))
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(title, fontSize = 13.sp, color = SevaInk900, lineHeight = 18.sp)
                Spacer(Modifier.height(3.dp))
                Text(relativeTime, fontSize = 11.sp, color = SevaInk400)
            }
            if (unread) {
                Box(
                    modifier = Modifier
                        .padding(top = 6.dp)
                        .size(6.dp)
                        .clip(CircleShape)
                        .background(SevaDanger500),
                )
            }
        }
        if (!isLast) {
            Box(modifier = Modifier.fillMaxWidth().height(1.dp).background(BorderDefault))
        }
    }
}

private fun greetingForNow(): String {
    val h = java.time.LocalTime.now().hour
    return when {
        h < 12 -> "Good morning"
        h < 17 -> "Good afternoon"
        else -> "Good evening"
    }
}

private fun relativeTime(at: Instant?): String {
    if (at == null) return ""
    val d = Duration.between(at, Instant.now())
    val mins = d.toMinutes()
    return when {
        mins < 1 -> "just now"
        mins < 60 -> "${mins}m ago"
        mins < 60 * 24 -> "${mins / 60}h ago"
        else -> "${mins / (60 * 24)}d ago"
    }
}

