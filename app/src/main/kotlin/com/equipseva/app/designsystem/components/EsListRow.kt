package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Build
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Email
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900

// Touchable list row used everywhere settings rows live (Profile sub-
// pages, Notifications inbox, KYC sections). Optional leading icon-box
// + title + subtitle stack + trailing widget (chevron, pill, switch).
@Composable
fun EsListRow(
    title: String,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    leading: (@Composable () -> Unit)? = null,
    trailing: (@Composable () -> Unit)? = null,
    onClick: (() -> Unit)? = null,
    danger: Boolean = false,
) {
    val titleColor = if (danger) SevaDanger500 else SevaInk900
    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(Color.White)
            .let {
                if (onClick != null) {
                    // Role.Button gives TalkBack the verb hint
                    // ("double-tap to activate") instead of the
                    // generic clickable-row announcement. EsListRow
                    // is the workhorse for the Profile, Notification
                    // inbox, KYC sections — adding the role here
                    // ripples to every settings/list row in the app.
                    it.clickable(onClick = onClick, role = Role.Button)
                } else {
                    it
                }
            }
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        if (leading != null) {
            Box(modifier = Modifier.size(36.dp), contentAlignment = Alignment.Center) { leading() }
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(text = title, style = EsType.Label, color = titleColor)
            if (subtitle != null) {
                Text(
                    text = subtitle,
                    style = EsType.Caption,
                    color = SevaInk500,
                    modifier = Modifier.padding(top = 2.dp),
                )
            }
        }
        if (trailing != null) trailing()
    }
}

// ---- Previews — design-system gallery. Every @Preview under designsystem/
// is also a Roborazzi screenshot test (see app/build.gradle.kts), so a
// variant that is missing here has no visual regression guard.

@Composable
private fun EsListRowGallery() {
    val iconBox: @Composable (ImageVector) -> Unit = { icon ->
        Box(
            modifier = Modifier.size(36.dp).background(SevaGreen50, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = SevaGreen700,
                modifier = Modifier.size(20.dp),
            )
        }
    }
    val chevron: @Composable () -> Unit = {
        Icon(imageVector = Icons.Outlined.ChevronRight, contentDescription = null, tint = SevaInk500)
    }
    Column(
        modifier = Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(text = "Static (no onClick)", style = EsType.Caption, color = SevaInk500)
        EsListRow(title = "Hospital name")
        EsListRow(
            title = "Registered hospital",
            subtitle = "Apollo Hospitals, Jubilee Hills, Hyderabad",
        )
        EsListRow(
            title = "KYC status",
            subtitle = "Verified on 12 Aug 2026",
            trailing = { Pill(text = "Verified", kind = PillKind.Success) },
        )
        EsListRow(
            title = "Ventilator repair",
            leading = { iconBox(Icons.Outlined.Build) },
            trailing = { Pill(text = "In progress", kind = PillKind.Warn) },
        )

        Text(text = "Clickable", style = EsType.Caption, color = SevaInk500)
        EsListRow(title = "Edit profile", trailing = chevron, onClick = {})
        EsListRow(
            title = "Service address",
            subtitle = "Plot 14, Banjara Hills, Hyderabad 500034",
            leading = { iconBox(Icons.Outlined.Home) },
            trailing = chevron,
            onClick = {},
        )
        EsListRow(
            title = "Engineer profile",
            subtitle = "Ravi Kumar · Biomedical Engineer · 8 yrs",
            leading = { iconBox(Icons.Outlined.Person) },
            trailing = chevron,
            onClick = {},
        )
        EsListRow(
            title = "Pending payout",
            leading = { iconBox(Icons.Outlined.Build) },
            trailing = { Pill(text = "₹4,500", kind = PillKind.Lime) },
            onClick = {},
        )
        EsListRow(
            title = "Job alerts",
            subtitle = "Get notified when a new repair job matches your skills",
            leading = { iconBox(Icons.Outlined.Notifications) },
            trailing = { Switch(checked = true, onCheckedChange = {}) },
        )
        EsListRow(
            title = "Promotional emails",
            leading = { iconBox(Icons.Outlined.Email) },
            trailing = { Switch(checked = false, onCheckedChange = {}) },
        )

        Text(text = "Danger", style = EsType.Caption, color = SevaInk500)
        EsListRow(title = "Log out", danger = true, onClick = {})
        EsListRow(
            title = "Delete account",
            subtitle = "Removes your KYC documents and job history permanently",
            leading = { iconBox(Icons.Outlined.Delete) },
            trailing = chevron,
            onClick = {},
            danger = true,
        )

        Text(text = "Edge cases", style = EsType.Caption, color = SevaInk500)
        EsListRow(title = "", subtitle = "Empty title", trailing = chevron, onClick = {})
        EsListRow(
            title = "Philips IntelliVue MX450 patient monitor — annual preventive maintenance and calibration",
            subtitle = "Kokilaben Dhirubhai Ambani Hospital, Andheri West, Mumbai 400053 · ICU Wing B · Quote ₹12,000 pending approval",
            leading = { iconBox(Icons.Outlined.Build) },
            trailing = chevron,
            onClick = {},
        )
    }
}

@Preview(name = "EsListRow", showBackground = true)
@Composable
private fun EsListRowPreview() {
    EquipSevaTheme(darkTheme = false) { EsListRowGallery() }
}

@Preview(name = "EsListRow large text", showBackground = true, fontScale = 1.3f)
@Composable
private fun EsListRowPreviewLargeText() {
    EquipSevaTheme(darkTheme = false) { EsListRowGallery() }
}
