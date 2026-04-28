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
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material.icons.outlined.NotificationsNone
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
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
import com.equipseva.app.designsystem.theme.EsType
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
                                    modifier = Modifier.size(20.dp),
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
                                modifier = Modifier.size(20.dp),
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
        style = EsType.Overline,
        color = SevaInk500,
        modifier = Modifier
            .fillMaxWidth()
            .background(PaperDefault)
            .padding(horizontal = 16.dp, vertical = 8.dp),
    )
}

@Composable
private fun NotificationRow(
    notification: Notification,
    onClick: () -> Unit,
) {
    val rowBg = if (notification.isUnread) SevaGreen50 else Color.White
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(rowBg)
            .border(0.5.dp, BorderDefault, RoundedCornerShape(0.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 14.dp),
    ) {
        Row(
            verticalAlignment = Alignment.Top,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            KindIcon(kind = notification.kind)
            Column(modifier = Modifier.weight(1f)) {
                val titleStyle = if (notification.isUnread) {
                    EsType.Body.copy(fontWeight = FontWeight.SemiBold)
                } else {
                    EsType.Body
                }
                Text(
                    text = notification.title.ifBlank { notification.body },
                    style = titleStyle,
                    color = SevaInk900,
                    lineHeight = 18.sp,
                )
                if (notification.body.isNotBlank() && notification.title.isNotBlank()) {
                    Spacer(Modifier.height(2.dp))
                    Text(
                        text = notification.body,
                        style = EsType.Caption,
                        color = SevaInk500,
                    )
                }
                Spacer(Modifier.height(4.dp))
                notification.sentAt?.let {
                    Text(
                        text = relativeLabel(it) + " ago",
                        style = EsType.Caption,
                        color = SevaInk400,
                    )
                }
            }
            if (notification.isUnread) {
                Box(
                    modifier = Modifier
                        .padding(top = 6.dp)
                        .size(8.dp)
                        .clip(CircleShape)
                        .background(SevaDanger500),
                )
            }
        }
    }
}

@Composable
private fun KindIcon(kind: String?) {
    val (icon, tint) = iconForKind(kind)
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

private fun iconForKind(kind: String?): Pair<ImageVector, Color> = when (kind) {
    "bid", "job_bid", "bid_accepted" -> Icons.Filled.CurrencyRupee to SevaGreen700
    "msg", "chat", "message" -> Icons.AutoMirrored.Filled.Chat to SevaGreen700
    "kyc", "verification" -> Icons.Filled.Shield to SevaInfo500
    "status", "job_status", "job_state" -> Icons.Filled.Bolt to SevaWarning500
    else -> Icons.Filled.Bolt to SevaGreen700
}

private fun groupByDay(rows: List<Notification>): List<Pair<String, List<Notification>>> {
    val zone = ZoneId.systemDefault()
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

