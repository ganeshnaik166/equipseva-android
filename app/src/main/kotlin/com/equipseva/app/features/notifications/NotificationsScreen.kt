package com.equipseva.app.features.notifications

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Build
import androidx.compose.material.icons.outlined.Chat
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.outlined.ReceiptLong
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreen50
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface100
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.designsystem.theme.Surface50

/**
 * Notification preferences. Per design spec this is a settings screen — push/email
 * toggles per category. State is local for now; persistence + a real preferences
 * repository land in a follow-up PR.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NotificationsScreen(
    onBack: () -> Unit,
) {
    Scaffold(
        topBar = { ESBackTopBar(title = "Notifications", onBack = onBack) },
        containerColor = Surface50,
    ) { inner ->
        val groups = remember { defaultGroups() }
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(inner),
            contentPadding = PaddingValues(horizontal = Spacing.lg, vertical = Spacing.md),
            verticalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            item("groups_card") {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(MaterialTheme.shapes.medium)
                        .background(MaterialTheme.colorScheme.surface)
                        .border(1.dp, Surface200, MaterialTheme.shapes.medium),
                ) {
                    groups.forEachIndexed { i, group ->
                        PreferenceGroupRow(group = group)
                        if (i < groups.lastIndex) {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(1.dp)
                                    .background(Surface100),
                            )
                        }
                    }
                }
            }
            item("hint") {
                Text(
                    text = "We'll only send notifications for events you opt in to.",
                    fontSize = 12.sp,
                    color = Ink500,
                    modifier = Modifier.padding(top = Spacing.xs, start = Spacing.xs),
                )
            }
        }
    }
}

private data class PreferenceGroup(
    val key: String,
    val label: String,
    val icon: ImageVector,
    val defaultPush: Boolean,
    val defaultEmail: Boolean,
)

private fun defaultGroups(): List<PreferenceGroup> = listOf(
    PreferenceGroup("orders", "Orders", Icons.Outlined.ReceiptLong, defaultPush = true, defaultEmail = true),
    PreferenceGroup("jobs", "Jobs", Icons.Outlined.Build, defaultPush = true, defaultEmail = false),
    PreferenceGroup("chat", "Chat", Icons.Outlined.Chat, defaultPush = true, defaultEmail = false),
    PreferenceGroup("account", "Account", Icons.Outlined.Person, defaultPush = false, defaultEmail = true),
)

@Composable
private fun PreferenceGroupRow(group: PreferenceGroup) {
    var push by remember(group.key) { mutableStateOf(group.defaultPush) }
    var email by remember(group.key) { mutableStateOf(group.defaultEmail) }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.md, vertical = Spacing.md),
        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(BrandGreen50),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = group.icon,
                    contentDescription = null,
                    tint = BrandGreenDark,
                    modifier = Modifier.size(18.dp),
                )
            }
            Text(
                text = group.label,
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                color = Ink900,
            )
        }
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            ChannelToggleTile(
                label = "Push",
                checked = push,
                onCheckedChange = { push = it },
                modifier = Modifier.weight(1f),
            )
            ChannelToggleTile(
                label = "Email",
                checked = email,
                onCheckedChange = { email = it },
                modifier = Modifier.weight(1f),
            )
        }
    }
}

@Composable
private fun ChannelToggleTile(
    label: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .clip(MaterialTheme.shapes.small)
            .background(Surface50)
            .padding(horizontal = 12.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        Text(
            text = label,
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = Ink900,
            modifier = Modifier.weight(1f),
        )
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            colors = SwitchDefaults.colors(
                checkedThumbColor = MaterialTheme.colorScheme.surface,
                checkedTrackColor = BrandGreen,
                uncheckedThumbColor = MaterialTheme.colorScheme.surface,
                uncheckedTrackColor = Surface200,
                uncheckedBorderColor = Surface200,
            ),
        )
    }
}
