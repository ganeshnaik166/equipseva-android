package com.equipseva.app.features.notifications

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
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.theme.Spacing

/**
 * Notifications inbox. Stub UI for now — backend table `notifications` and a
 * realtime subscription land in a follow-up PR. The demo rows below are static
 * so the entry point, navigation, and layout can ship independently.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NotificationsScreen(
    onBack: () -> Unit,
) {
    Scaffold(
        topBar = { ESBackTopBar(title = "Notifications", onBack = onBack) },
    ) { inner ->
        val demo = demoNotifications()
        if (demo.isEmpty()) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(inner),
            ) {
                EmptyStateView(
                    icon = Icons.Outlined.Notifications,
                    title = "You're all caught up",
                    subtitle = "New bids, order updates, and messages will show up here.",
                )
            }
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(inner),
                contentPadding = PaddingValues(horizontal = Spacing.lg, vertical = Spacing.md),
                verticalArrangement = Arrangement.spacedBy(Spacing.sm),
            ) {
                items(items = demo, key = { it.id }) { item ->
                    NotificationCard(item)
                }
            }
        }
    }
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
