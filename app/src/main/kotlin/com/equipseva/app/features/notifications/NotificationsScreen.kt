package com.equipseva.app.features.notifications

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Chat
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.CurrencyRupee
import androidx.compose.material.icons.filled.DoneAll
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.Gavel
import androidx.compose.material.icons.automirrored.filled.HelpOutline
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.outlined.Block
import androidx.compose.material.icons.outlined.NotificationsNone
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.data.notifications.Notification
import com.equipseva.app.core.util.relativeLabel
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInfo500
import com.equipseva.app.designsystem.theme.SevaInk400
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.designsystem.theme.SevaWarning500
import com.equipseva.app.navigation.NotificationDeepLink
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NotificationsScreen(
    onBack: () -> Unit,
    onOpenRoute: (String) -> Unit = {},
    onOpenDeepLink: (String) -> Unit = {},
    onOpenSettings: () -> Unit = {},
    viewModel: NotificationsInboxViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(
                title = "Notifications",
                onBack = onBack,
                right = {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        if (state.hasUnread) {
                            Box(
                                modifier = Modifier
                                    .size(36.dp)
                                    .clip(CircleShape)
                                    .clickable(onClick = viewModel::markAllRead),
                                contentAlignment = Alignment.Center,
                            ) {
                                Icon(
                                    Icons.Filled.DoneAll,
                                    contentDescription = "Mark all read",
                                    tint = SevaGreen700,
                                    modifier = Modifier.size(18.dp),
                                )
                            }
                        }
                        Box(
                            modifier = Modifier
                                .size(36.dp)
                                .clip(CircleShape)
                                .clickable(onClick = onOpenSettings),
                            contentAlignment = Alignment.Center,
                        ) {
                            Icon(
                                Icons.Outlined.Settings,
                                contentDescription = "Notification settings",
                                tint = SevaInk700,
                                modifier = Modifier.size(18.dp),
                            )
                        }
                    }
                },
            )
            ErrorBanner(message = state.errorMessage)
            when {
                state.loading && state.rows.isEmpty() -> Box(
                    Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center,
                ) { CircularProgressIndicator() }
                state.rows.isEmpty() -> EmptyStateView(
                    icon = Icons.Outlined.NotificationsNone,
                    title = "Nothing here yet",
                    subtitle = "We'll let you know when there's news.",
                )
                else -> PullToRefreshBox(
                    isRefreshing = state.refreshing,
                    onRefresh = viewModel::refresh,
                    modifier = Modifier.fillMaxSize(),
                ) {
                    val grouped = remember(state.rows) { groupByDay(state.rows) }
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(vertical = 4.dp),
                    ) {
                        grouped.forEach { (header, rows) ->
                            item(key = "h_$header") { DayHeader(label = header) }
                            items(items = rows, key = { it.id }) { row ->
                                NotificationRow(
                                    notification = row,
                                    onClick = {
                                        if (row.isUnread) viewModel.markRead(row.id)
                                        val resolved = NotificationDeepLink.routeFor(row.kind, row.data)
                                        if (resolved != null) {
                                            onOpenRoute(resolved)
                                        } else {
                                            row.deepLink?.takeIf { it.isNotBlank() }?.let(onOpenDeepLink)
                                        }
                                    },
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun DayHeader(label: String) {
    Text(
        text = label,
        fontSize = 12.sp,
        fontWeight = FontWeight.SemiBold,
        color = SevaInk700,
        modifier = Modifier
            .fillMaxWidth()
            .background(PaperDefault)
            .padding(start = 16.dp, end = 16.dp, top = 12.dp, bottom = 8.dp),
    )
}

@Composable
private fun NotificationRow(
    notification: Notification,
    onClick: () -> Unit,
) {
    val rowBg = if (notification.isUnread) SevaGreen50 else Color.Transparent
    Column(modifier = Modifier.fillMaxWidth().background(rowBg)) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(onClick = onClick)
                .padding(horizontal = 16.dp, vertical = 14.dp),
            verticalAlignment = Alignment.Top,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            KindIcon(kind = notification.kind, data = notification.data)
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = notification.title.ifBlank { notification.body },
                    fontSize = 13.sp,
                    fontWeight = if (notification.isUnread) FontWeight.SemiBold else FontWeight.Normal,
                    color = SevaInk900,
                    lineHeight = (13 * 1.4f).sp,
                )
                if (notification.body.isNotBlank() && notification.title.isNotBlank()) {
                    Spacer(Modifier.height(2.dp))
                    Text(
                        text = notification.body,
                        fontSize = 11.sp,
                        color = SevaInk500,
                        lineHeight = (11 * 1.4f).sp,
                    )
                }
                notification.sentAt?.let {
                    Spacer(Modifier.height(4.dp))
                    Text(
                        // relativeLabel returns "now" / "5m" / "3h" / "2d" — appending
                        // " ago" produces "now ago" (broken) while looking right for "5m".
                        // Sibling chat row uses bare relativeLabel for the same data; match.
                        text = relativeLabel(it),
                        fontSize = 11.sp,
                        color = SevaInk400,
                    )
                }
            }
            if (notification.isUnread) {
                Box(
                    modifier = Modifier
                        .padding(top = 4.dp)
                        .size(8.dp)
                        .clip(CircleShape)
                        .background(SevaDanger500),
                )
            }
        }
        HorizontalDivider(color = BorderDefault, thickness = 1.dp)
    }
}

@Composable
private fun KindIcon(kind: String?, data: Map<String, String> = emptyMap()) {
    val (icon, tint) = iconForKind(kind, data)
    Box(
        modifier = Modifier
            .size(36.dp)
            .clip(RoundedCornerShape(8.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(8.dp)),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(16.dp))
    }
}

private fun iconForKind(
    kind: String?,
    data: Map<String, String> = emptyMap(),
): Pair<ImageVector, Color> = when (kind) {
    // Money / commerce kinds — green ₹.
    "repair_bid_new",
    "repair_bid_accepted",
    "repair_bid_rejected",
    "cost_revision_proposed",
    "cost_revision_approved",
    "cost_revision_rejected" -> Icons.Filled.CurrencyRupee to SevaGreen700
    // Chat.
    "chat_message_new" -> Icons.AutoMirrored.Filled.Chat to SevaGreen700
    // KYC.
    "kyc_status_changed" -> Icons.Filled.Shield to SevaInfo500
    // Repair-job lifecycle alerts.
    "repair_job_cancelled" -> Icons.Filled.Bolt to SevaDanger500
    // Rating prompts.
    "rate_engineer", "rate_hospital" -> Icons.Filled.Star to SevaWarning500
    // PR-D31 commission tier upgrade celebration — green star.
    "commission_tier_upgraded" -> Icons.Filled.Star to SevaGreen700
    // Warranty (PR-D9 / PR-D12).
    "warranty_covered", "warranty_fee_waived" -> Icons.Filled.Verified to SevaGreen700
    // AMC (PR-C series).
    "amc_loyal_pair_nudge",
    "amc_visit_assigned",
    "amc_visit_engineer_assigned",
    "amc_visit_engineer_changed",
    "amc_visit_pending_assignment" -> Icons.Filled.Build to SevaInfo500
    // Round 331 — escalate icon tint by stage. Round 326 cadence
    // attaches data["stage"] = "1" | "2" | "3". Stage 3 (1-day window)
    // gets the Danger tint so it visually stands apart from earlier
    // reminders in a backed-up inbox.
    "amc_renewal_due" -> Icons.Filled.Build to (
        when (data["stage"]) {
            "3" -> SevaDanger500
            else -> SevaWarning500
        }
    )
    "amc_sla_breach",
    "amc_admin_escalation_raised" -> Icons.Filled.Build to SevaDanger500
    // Cash survey + auto-suspend (PR-D1 / PR-D11).
    "cash_survey" -> Icons.AutoMirrored.Filled.HelpOutline to SevaWarning500
    // Spot-audit invitation (PR-D43).
    "spot_audit_invited" -> Icons.Filled.Star to SevaInfo500
    "engineer_auto_suspended",
    "admin_engineer_auto_suspended" -> Icons.Outlined.Block to SevaDanger500
    // Escrow disputes (PR-D22 + PR-D28).
    "escrow_dispute_opened",
    "admin_escrow_dispute_opened" -> Icons.Filled.Gavel to SevaDanger500
    "escrow_dispute_resolved" -> Icons.Filled.Gavel to SevaGreen700
    // Generic notification fallback.
    else -> Icons.Filled.Bolt to SevaGreen700
}

private fun groupByDay(rows: List<Notification>): List<Pair<String, List<Notification>>> {
    // Pin to IST: EquipSeva is India-only and hospitals expect
    // Today / Yesterday headers to match wall-clock IST, not whatever
    // ZoneId the device happens to be on (some carrier-flashed Realme
    // units default to UTC, which would shift grouping by 5.5 hours).
    val zone = ZoneId.of("Asia/Kolkata")
    val today = LocalDate.now(zone)
    val groups = linkedMapOf<String, MutableList<Notification>>()
    rows.forEach { n ->
        val sent = n.sentAt ?: Instant.EPOCH
        val date = sent.atZone(zone).toLocalDate()
        val days = Duration.between(date.atStartOfDay(zone), today.atStartOfDay(zone)).toDays()
        val header = when {
            days <= 0L -> "Today"
            days == 1L -> "Yesterday"
            days < 7L -> "Last week"
            else -> "Earlier"
        }
        groups.getOrPut(header) { mutableListOf() }.add(n)
    }
    return groups.map { it.key to it.value }
}

