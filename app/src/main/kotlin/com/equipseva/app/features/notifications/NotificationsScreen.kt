package com.equipseva.app.features.notifications

import android.app.TimePickerDialog
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Assignment
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.data.prefs.QuietHoursPrefs
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.theme.Spacing

/**
 * Notifications inbox + per-category push settings. The inbox rows below are
 * still static demo data (backend `notifications` table lands in a follow-up);
 * the "Push categories" block at the top is live and persists mute choices to
 * DataStore via [NotificationSettingsViewModel].
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NotificationsScreen(
    onBack: () -> Unit,
    settingsViewModel: NotificationSettingsViewModel = hiltViewModel(),
) {
    val categories by settingsViewModel.categories.collectAsStateWithLifecycle()
    val quietHours by settingsViewModel.quietHours.collectAsStateWithLifecycle()
    Scaffold(
        topBar = { ESBackTopBar(title = "Notifications", onBack = onBack) },
    ) { inner ->
        val demo = demoNotifications()
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(inner),
            contentPadding = PaddingValues(horizontal = Spacing.lg, vertical = Spacing.md),
            verticalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            item(key = "settings-header") {
                Text(
                    text = "Push categories",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.padding(top = Spacing.xs, bottom = Spacing.xxs),
                )
            }
            items(items = categories, key = { "toggle-" + it.channelId }) { toggle ->
                PushCategoryToggleRow(
                    toggle = toggle,
                    onToggle = { settingsViewModel.toggle(toggle.channelId) },
                )
            }
            item(key = "quiet-hours-header") {
                Text(
                    text = "Quiet hours",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.padding(top = Spacing.lg, bottom = Spacing.xxs),
                )
            }
            item(key = "quiet-hours-card") {
                QuietHoursCard(
                    prefs = quietHours,
                    onEnabledChange = settingsViewModel::setQuietHoursEnabled,
                    onWindowChange = settingsViewModel::setQuietHoursWindow,
                )
            }
            item(key = "inbox-header") {
                Text(
                    text = "Inbox",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.padding(top = Spacing.lg, bottom = Spacing.xxs),
                )
            }
            if (demo.isEmpty()) {
                item(key = "inbox-empty") {
                    EmptyStateView(
                        icon = Icons.Outlined.Notifications,
                        title = "You're all caught up",
                        subtitle = "New bids, order updates, and messages will show up here.",
                    )
                }
            } else {
                items(items = demo, key = { it.id }) { item ->
                    NotificationCard(item)
                }
            }
        }
    }
}

@Composable
private fun PushCategoryToggleRow(
    toggle: PushCategoryToggle,
    onToggle: () -> Unit,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(Spacing.lg),
            horizontalArrangement = Arrangement.spacedBy(Spacing.md),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(Spacing.xxs),
            ) {
                Text(
                    text = toggle.label,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    text = toggle.description,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            // `muted = true` means the toggle reads "off" to the user (push is
            // silenced). Invert so the Switch visual matches expectations.
            Switch(
                checked = !toggle.muted,
                onCheckedChange = { onToggle() },
            )
        }
    }
}

@Composable
private fun QuietHoursCard(
    prefs: QuietHoursPrefs,
    onEnabledChange: (Boolean) -> Unit,
    onWindowChange: (Int, Int) -> Unit,
) {
    val context = LocalContext.current
    val startLabel = formatMinutes(prefs.startMinutes)
    val endLabel = formatMinutes(prefs.endMinutes)

    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(Spacing.md),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(Spacing.xxs),
                ) {
                    Text(
                        text = "Do Not Disturb",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Text(
                        text = if (prefs.enabled) {
                            "Silenced from $startLabel to $endLabel"
                        } else {
                            "Silently drop pushes during your chosen window."
                        },
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Switch(
                    checked = prefs.enabled,
                    onCheckedChange = onEnabledChange,
                )
            }
            if (prefs.enabled) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
                ) {
                    TextButton(
                        onClick = {
                            TimePickerDialog(
                                context,
                                { _, hour, minute ->
                                    onWindowChange(hour * 60 + minute, prefs.endMinutes)
                                },
                                prefs.startMinutes / 60,
                                prefs.startMinutes % 60,
                                true,
                            ).show()
                        },
                    ) { Text("Start: $startLabel") }
                    TextButton(
                        onClick = {
                            TimePickerDialog(
                                context,
                                { _, hour, minute ->
                                    onWindowChange(prefs.startMinutes, hour * 60 + minute)
                                },
                                prefs.endMinutes / 60,
                                prefs.endMinutes % 60,
                                true,
                            ).show()
                        },
                    ) { Text("End: $endLabel") }
                }
            }
        }
    }
}

private fun formatMinutes(minutes: Int): String {
    val safe = minutes.coerceIn(0, 24 * 60 - 1)
    val h = safe / 60
    val m = safe % 60
    return "%02d:%02d".format(h, m)
}

private data class DemoNotification(
    val id: String,
    val icon: ImageVector,
    val title: String,
    val body: String,
    val timeAgo: String,
)

/**
 * Hardcoded demo list. Replace with a real repository-backed flow once the
 * `notifications` table + realtime channel are wired on the server.
 */
@Composable
private fun demoNotifications(): List<DemoNotification> = listOf(
    DemoNotification(
        id = "demo-1",
        icon = Icons.AutoMirrored.Filled.Assignment,
        title = "New bid received",
        body = "A supplier quoted ₹45,000 on your ultrasound RFQ.",
        timeAgo = "2m ago",
    ),
    DemoNotification(
        id = "demo-2",
        icon = Icons.Filled.LocalShipping,
        title = "Order shipped",
        body = "Order ES-1747651200-4821 is out for delivery.",
        timeAgo = "1h ago",
    ),
    DemoNotification(
        id = "demo-3",
        icon = Icons.Filled.CheckCircle,
        title = "Repair job completed",
        body = "Engineer marked the MRI service as complete. Rate your experience.",
        timeAgo = "Yesterday",
    ),
)

@Composable
private fun NotificationCard(item: DemoNotification) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(Spacing.lg),
            horizontalArrangement = Arrangement.spacedBy(Spacing.md),
            verticalAlignment = Alignment.Top,
        ) {
            Icon(
                imageVector = item.icon,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
            )
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(Spacing.xxs),
            ) {
                Text(
                    text = item.title,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    text = item.body,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    text = item.timeAgo,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}
