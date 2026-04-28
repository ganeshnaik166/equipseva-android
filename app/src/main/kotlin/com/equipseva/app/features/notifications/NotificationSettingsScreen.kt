package com.equipseva.app.features.notifications

import android.app.TimePickerDialog
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.data.prefs.QuietHoursPrefs
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900

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
    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "Notification settings", onBack = onBack)
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                item(key = "header") {
                    Text(
                        text = "Push categories",
                        style = EsType.H5,
                        color = SevaInk900,
                        modifier = Modifier.padding(top = 4.dp, bottom = 4.dp),
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
                        style = EsType.H5,
                        color = SevaInk900,
                        modifier = Modifier.padding(top = 16.dp, bottom = 4.dp),
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
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "Silence push during a window",
                    style = EsType.Body,
                    color = SevaInk900,
                )
                Text(
                    text = "Notifications will arrive in your inbox but won't pop on your screen.",
                    style = EsType.Caption,
                    color = SevaInk500,
                )
            }
            Switch(
                checked = prefs.enabled,
                onCheckedChange = onToggle,
                colors = SwitchDefaults.colors(checkedTrackColor = SevaGreen700),
            )
        }
        if (prefs.enabled) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "${formatMinutes(prefs.startMinutes)} – ${formatMinutes(prefs.endMinutes)}",
                    style = EsType.Body,
                    color = SevaInk900,
                    modifier = Modifier.weight(1f),
                )
                TextButton(onClick = {
                    TimePickerDialog(
                        context,
                        { _, h, m -> onWindowChange(h * 60 + m, prefs.endMinutes) },
                        prefs.startMinutes / 60,
                        prefs.startMinutes % 60,
                        true,
                    ).show()
                }) { Text("Start", color = SevaGreen700) }
                TextButton(onClick = {
                    TimePickerDialog(
                        context,
                        { _, h, m -> onWindowChange(prefs.startMinutes, h * 60 + m) },
                        prefs.endMinutes / 60,
                        prefs.endMinutes % 60,
                        true,
                    ).show()
                }) { Text("End", color = SevaGreen700) }
            }
        }
    }
}

@Composable
private fun PushCategoryToggleRow(
    toggle: PushCategoryToggle,
    onToggle: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(14.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(text = toggle.label, style = EsType.Body, color = SevaInk900)
            Text(text = toggle.description, style = EsType.Caption, color = SevaInk500)
        }
        Switch(
            checked = !toggle.muted,
            onCheckedChange = { onToggle() },
            colors = SwitchDefaults.colors(checkedTrackColor = SevaGreen700),
        )
    }
}
