package com.equipseva.app.features.notifications

import android.app.TimePickerDialog
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.selection.toggleable
import androidx.compose.ui.semantics.Role
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.data.prefs.QuietHoursPrefs
import com.equipseva.app.designsystem.components.EsField
import com.equipseva.app.designsystem.components.EsSection
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.BorderStrong
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.designsystem.theme.SevaWarning50
import com.equipseva.app.designsystem.theme.SevaWarning500

/**
 * Per-category push mute toggles. Backed by [NotificationSettingsViewModel],
 * which writes through to DataStore via `UserPrefs.setMutedPushCategories`
 * (PR #173). Lives at `Routes.NOTIFICATION_SETTINGS` — separate from the
 * realtime inbox at `Routes.NOTIFICATIONS`.
 *
 * Re-skinned to match `screens-comm.jsx:NotificationSettings` (lines 152-189):
 * EsSection wrappers, single white-card with 1dp inter-row dividers, custom
 * 44x26 toggle pill, and a side-by-side quiet-hours card with two EsField
 * inputs. Switch -> custom toggle is intentional per spec.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NotificationSettingsScreen(
    onBack: () -> Unit,
    viewModel: NotificationSettingsViewModel = hiltViewModel(),
) {
    val categories by viewModel.categories.collectAsStateWithLifecycle()
    val quietHours by viewModel.quietHours.collectAsStateWithLifecycle()
    val context = LocalContext.current
    // Check on every recomposition so the banner clears the moment the
    // user returns from Settings having granted POST_NOTIFICATIONS.
    val systemNotificationsEnabled = androidx.core.app.NotificationManagerCompat
        .from(context).areNotificationsEnabled()
    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "Notification settings", onBack = onBack)
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(bottom = 24.dp),
            ) {
                if (!systemNotificationsEnabled) {
                    item(key = "perm_denied_banner") {
                        PermissionDeniedBanner(onOpenSystemSettings = {
                            val intent = android.content.Intent(
                                android.provider.Settings.ACTION_APP_NOTIFICATION_SETTINGS,
                            ).putExtra(
                                android.provider.Settings.EXTRA_APP_PACKAGE,
                                context.packageName,
                            )
                            runCatching { context.startActivity(intent) }
                        })
                    }
                }
                item(key = "categories") {
                    EsSection(title = "Categories") {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp, vertical = 12.dp)
                                .clip(RoundedCornerShape(12.dp))
                                .background(Color.White)
                                .border(1.dp, BorderDefault, RoundedCornerShape(12.dp)),
                        ) {
                            categories.forEachIndexed { index, toggle ->
                                CategoryRow(
                                    toggle = toggle,
                                    onToggle = { viewModel.toggle(toggle.channelId) },
                                )
                                if (index < categories.lastIndex) {
                                    Box(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .height(1.dp)
                                            .background(BorderDefault),
                                    )
                                }
                            }
                        }
                    }
                }
                item(key = "quiet") {
                    EsSection(title = "Quiet hours") {
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
}

internal fun formatMinutes(min: Int, is24Hour: Boolean = true): String {
    val safe = ((min % (24 * 60)) + 24 * 60) % (24 * 60)
    val hour24 = safe / 60
    val minute = safe % 60
    // Locale.US so "00..23" + "00..59" formats with ASCII digits even
    // on Hindi-default devices (Char.format would otherwise produce
    // Devanagari numerals on Hindi locale).
    if (is24Hour) return "%02d:%02d".format(java.util.Locale.US, hour24, minute)
    // 12-hour rendering for locales that use AM/PM (most Indian users
    // expect 10:00 PM, not 22:00, on the readout — matches the picker
    // shown by android.text.format.DateFormat.is24HourFormat).
    val period = if (hour24 < 12) "AM" else "PM"
    val hour12 = when {
        hour24 == 0 -> 12
        hour24 > 12 -> hour24 - 12
        else -> hour24
    }
    return "%d:%02d %s".format(java.util.Locale.US, hour12, minute, period)
}

@Composable
private fun CategoryRow(
    toggle: PushCategoryToggle,
    onToggle: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(14.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = toggle.label,
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
                color = SevaInk900,
            )
            Text(
                text = toggle.description,
                fontSize = 11.sp,
                color = SevaInk500,
                modifier = Modifier.padding(top = 2.dp),
            )
        }
        EsToggle(on = !toggle.muted, onClick = onToggle)
    }
}

// 44x26 pill toggle with 20x20 white thumb. Mirrors the JSX `<Toggle>`
// helper inside `screens-comm.jsx:NotificationSettings` — green-700 on,
// borderStrong off, 200ms ease on the thumb x-offset.
//
// Round 444 — wired through toggleable + Role.Switch so TalkBack
// announces "Switch, on / off" instead of generic "double-tap to
// activate". Critical because this composable drives the entire
// notification-mute matrix + quiet-hours toggle.
@Composable
private fun EsToggle(on: Boolean, onClick: () -> Unit) {
    val thumbX by animateDpAsState(
        targetValue = if (on) 21.dp else 3.dp,
        animationSpec = tween(durationMillis = 200),
        label = "es-toggle-thumb",
    )
    Box(
        modifier = Modifier
            .size(width = 44.dp, height = 26.dp)
            .clip(RoundedCornerShape(999.dp))
            .background(if (on) SevaGreen700 else BorderStrong)
            .toggleable(
                value = on,
                onValueChange = { onClick() },
                role = Role.Switch,
            ),
    ) {
        Box(
            modifier = Modifier
                .offset(x = thumbX, y = 3.dp)
                .size(20.dp)
                .clip(CircleShape)
                .background(Color.White),
        )
    }
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
            .padding(horizontal = 16.dp, vertical = 12.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "Silence push during a window",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium,
                    color = SevaInk900,
                )
                Text(
                    text = "Notifications still land in your inbox.",
                    fontSize = 11.sp,
                    color = SevaInk500,
                    modifier = Modifier.padding(top = 2.dp),
                )
            }
            EsToggle(on = prefs.enabled, onClick = { onToggle(!prefs.enabled) })
        }
        if (prefs.enabled) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                EsField(
                    value = formatMinutes(prefs.startMinutes, is24Hour = android.text.format.DateFormat.is24HourFormat(context)),
                    onChange = {},
                    label = "Start",
                    enabled = false,
                    modifier = Modifier
                        .weight(1f)
                        .clickable {
                            TimePickerDialog(
                                context,
                                { _, h, m -> onWindowChange(h * 60 + m, prefs.endMinutes) },
                                prefs.startMinutes / 60,
                                prefs.startMinutes % 60,
                                android.text.format.DateFormat.is24HourFormat(context),
                            ).show()
                        },
                )
                EsField(
                    value = formatMinutes(prefs.endMinutes, is24Hour = android.text.format.DateFormat.is24HourFormat(context)),
                    onChange = {},
                    label = "End",
                    enabled = false,
                    modifier = Modifier
                        .weight(1f)
                        .clickable {
                            TimePickerDialog(
                                context,
                                { _, h, m -> onWindowChange(prefs.startMinutes, h * 60 + m) },
                                prefs.endMinutes / 60,
                                prefs.endMinutes % 60,
                                android.text.format.DateFormat.is24HourFormat(context),
                            ).show()
                        },
                )
            }
            // Helper text — clarifies cross-midnight behaviour. End < Start
            // silently spans midnight (per QuietHours.isWithinWindow). Users
            // commonly set 22:00 → 07:00 thinking it means "9 hours overnight";
            // tell them that's how it reads.
            if (prefs.endMinutes != prefs.startMinutes) {
                val spansMidnight = prefs.endMinutes < prefs.startMinutes
                Text(
                    text = if (spansMidnight) {
                        "Quiet hours span midnight (overnight)."
                    } else {
                        "Quiet hours stay within the same day."
                    },
                    fontSize = 11.sp,
                    color = SevaInk500,
                )
            } else {
                // Start == End is a backend-silent disable in QuietHours.kt.
                // Surface it so the user doesn't think the toggle works.
                Text(
                    text = "Start and end can't match — quiet hours won't apply.",
                    fontSize = 11.sp,
                    color = SevaInk500,
                )
            }
        }
    }
}

@Composable
private fun PermissionDeniedBanner(onOpenSystemSettings: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(SevaWarning50)
            .border(1.dp, SevaWarning500.copy(alpha = 0.4f), RoundedCornerShape(12.dp))
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            text = "Notifications are turned off",
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold,
            color = SevaInk900,
        )
        Text(
            text = "EquipSeva can't post any notifications until you grant the permission in system Settings. " +
                "The toggles below still save your preferences for when it's re-enabled.",
            fontSize = 12.sp,
            color = SevaInk500,
        )
        Text(
            text = "Open system Settings",
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = SevaGreen700,
            modifier = Modifier.clickable(onClick = onOpenSystemSettings),
        )
    }
}
