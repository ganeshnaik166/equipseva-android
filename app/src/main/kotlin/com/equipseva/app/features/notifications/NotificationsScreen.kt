package com.equipseva.app.features.notifications

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DoneAll
import androidx.compose.material.icons.outlined.NotificationsNone
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.data.notifications.Notification
import com.equipseva.app.core.util.relativeLabel
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.navigation.NotificationDeepLink

/**
 * Real notifications inbox — pulls rows from `public.notifications` via
 * [NotificationsInboxViewModel], streams updates over Supabase Realtime, and
 * exposes per-row + bulk mark-read.
 *
 * The push-category mute toggles previously rendered here moved to
 * [NotificationSettingsScreen] (route `Routes.NOTIFICATION_SETTINGS`) so the
 * inbox stays a focused read-side surface.
 *
 * @param onOpenRoute invoked with a fully-formed in-app route string
 *   (e.g. `chat/detail/<uuid>`) resolved from the row's `kind` + `data`
 *   via [NotificationDeepLink]. Caller forwards directly to NavController.
 * @param onOpenDeepLink legacy fallback — invoked with the row's
 *   `data.deep_link` (or `action_url`) when [NotificationDeepLink] can't
 *   resolve a route from the row's `kind`. Older notifications shipped
 *   before PR #192 still flow through here. Rows with no link of either
 *   kind remain tap-targets for "mark read" only.
 */
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

    Scaffold(
        topBar = {
            ESBackTopBar(
                title = "Notifications",
                onBack = onBack,
                actions = {
                    if (state.hasUnread) {
                        IconButton(onClick = viewModel::markAllRead) {
                            Icon(
                                imageVector = Icons.Filled.DoneAll,
                                contentDescription = "Mark all read",
                            )
                        }
                    }
                    IconButton(onClick = onOpenSettings) {
                        Icon(
                            imageVector = Icons.Outlined.Settings,
                            contentDescription = "Notification settings",
                        )
                    }
                },
            )
        },
    ) { inner ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(inner),
        ) {
            ErrorBanner(
                message = state.errorMessage,
                modifier = Modifier.padding(horizontal = Spacing.lg),
            )
            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
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
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(
                            horizontal = Spacing.lg,
                            vertical = Spacing.md,
                        ),
                        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
                    ) {
                        items(items = state.rows, key = { it.id }) { row ->
                            NotificationRow(
                                notification = row,
                                onClick = {
                                    if (row.isUnread) viewModel.markRead(row.id)
                                    // Prefer the kind-based resolver — server PR #192 stamps
                                    // every push row with a known kind + ids. Fall back to the
                                    // legacy `data.deep_link` / `action_url` path so rows
                                    // emitted before the trigger landed still route correctly.
                                    val resolved = NotificationDeepLink.routeFor(row.kind, row.data)
                                    if (resolved != null) {
                                        onOpenRoute(resolved)
                                    } else {
                                        row.deepLink?.takeIf { it.isNotBlank() }?.let(onOpenDeepLink)
                                    }
                                },
                                onMarkRead = { viewModel.markRead(row.id) },
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun NotificationRow(
    notification: Notification,
    onClick: () -> Unit,
    onMarkRead: () -> Unit,
) {
    val cardColors = if (notification.isUnread) {
        CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
    } else {
        CardDefaults.cardColors()
    }
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
        colors = cardColors,
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(Spacing.lg),
            horizontalArrangement = Arrangement.spacedBy(Spacing.md),
            verticalAlignment = Alignment.Top,
        ) {
            UnreadDot(visible = notification.isUnread)
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(Spacing.xxs),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = notification.title,
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.weight(1f),
                    )
                    notification.sentAt?.let { instant ->
                        Text(
                            text = relativeLabel(instant),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                if (notification.body.isNotBlank()) {
                    Text(
                        text = notification.body,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                if (notification.isUnread) {
                    TextButton(
                        onClick = onMarkRead,
                        contentPadding = PaddingValues(horizontal = 0.dp),
                    ) {
                        Text("Mark read")
                    }
                }
            }
        }
    }
}

@Composable
private fun UnreadDot(visible: Boolean) {
    // Reserve the same width whether the dot is visible or not so the row
    // titles stay vertically aligned across read and unread rows.
    Box(
        modifier = Modifier.size(10.dp),
        contentAlignment = Alignment.Center,
    ) {
        if (visible) {
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.primary),
            )
        }
    }
}
