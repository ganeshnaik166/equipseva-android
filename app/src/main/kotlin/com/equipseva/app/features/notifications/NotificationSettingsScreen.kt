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
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.data.prefs.QuietHoursPrefs
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.theme.Spacing

/**
 * Per-category push mute toggles. Backed by [NotificationSettingsViewModel],
 * which writes through to DataStore via `UserPrefs.setMutedPushCategories`
 * (PR #173). Lives at `Routes.NOTIFICATION_SETTINGS` — separate from the
 * realtime inbox at `Routes.NOTIFICATIONS`.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NotificationSettingsScreen(
    onBack: () -> Unit,
    viewModel: NotificationSettingsViewModel = hiltViewModel(),
) {
    val categories by viewModel.categories.collectAsStateWithLifecycle()
    val quietHours by viewModel.quietHours.collectAsStateWithLifecycle()
    Scaffold(
        topBar = { ESBackTopBar(title = "Notification settings", onBack = onBack) },
    ) { inner ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(inner),
            contentPadding = PaddingValues(horizontal = Spacing.lg, vertical = Spacing.md),
            verticalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            item(key = "header") {
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
                    onToggle = { viewModel.toggle(toggle.channelId) },
                )
            }
            item(key = "quiet-header") {
                Text(
                    text = "Quiet hours",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.padding(top = Spacing.lg, bottom = Spacing.xxs),
                )
            }
            item(key = "quiet-card") {
                QuietHoursCard(
                    prefs = quietHours,
                    onToggle = viewModel::setQuietHoursEnabled,
                    onWindowChange = viewModel::setQuietHoursWindow,
                )
            }
        }
    }
}

private fun formatMinutes(min: Int): String {
    val safe = ((min % (24 * 60)) + 24 * 60) % (24 * 60)
    return "%02d:%02d".format(safe / 60, safe % 60)
}

@Composable
private fun QuietHoursCard(
    prefs: QuietHoursPrefs,
    onToggle: (Boolean) -> Unit,
    onWindowChange: (startMin: Int, endMin: Int) -> Unit,
) {
    val context = LocalContext.current
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
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = "Silence push during a window",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Text(
                        text = "Notifications will arrive in your inbox but won't pop on your screen.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Switch(checked = prefs.enabled, onCheckedChange = onToggle)
            }
            if (prefs.enabled) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(Spacing.md),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = "${formatMinutes(prefs.startMinutes)} – ${formatMinutes(prefs.endMinutes)}",
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.weight(1f),
                    )
                    androidx.compose.material3.TextButton(
                        onClick = {
                            TimePickerDialog(
                                context,
                                { _, h, m -> onWindowChange(h * 60 + m, prefs.endMinutes) },
                                prefs.startMinutes / 60,
                                prefs.startMinutes % 60,
                                true,
                            ).show()
                        },
                    ) { Text("Start") }
                    androidx.compose.material3.TextButton(
                        onClick = {
                            TimePickerDialog(
                                context,
                                { _, h, m -> onWindowChange(prefs.startMinutes, h * 60 + m) },
                                prefs.endMinutes / 60,
                                prefs.endMinutes % 60,
                                true,
                            ).show()
                        },
                    ) { Text("End") }
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
