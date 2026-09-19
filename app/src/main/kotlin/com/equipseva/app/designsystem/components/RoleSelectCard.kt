package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Build
import androidx.compose.material.icons.outlined.Engineering
import androidx.compose.material.icons.outlined.LocalHospital
import androidx.compose.material.icons.outlined.LocalShipping
import androidx.compose.material.icons.outlined.MedicalServices
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreen50
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface200

// Selectable card for the role picker. GradientTile + title + description + radio.
@Composable
fun RoleSelectCard(
    icon: ImageVector,
    title: String,
    description: String,
    hue: Int,
    selected: Boolean,
    onSelect: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    badge: String? = null,
) {
    val source = rememberTapInteractionSource()
    val borderColor = if (selected) BrandGreen else Surface200
    val bg = if (selected) BrandGreen50 else Surface0
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(MaterialTheme.shapes.large)
            .background(bg)
            .border(
                width = if (selected) 2.dp else 1.dp,
                color = borderColor,
                shape = MaterialTheme.shapes.large,
            )
            // Round 461: selectable + Role.RadioButton — onboarding
            // role picker now reads as a true radio group to TalkBack.
            .selectable(
                selected = selected,
                enabled = enabled,
                onClick = onSelect,
                role = androidx.compose.ui.semantics.Role.RadioButton,
                interactionSource = source,
                indication = null,
            )
            .tapScale(source)
            .padding(Spacing.lg)
            .alpha(if (enabled) 1f else 0.55f),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        GradientTile(icon = icon, hue = hue, size = 48.dp)
        Column(modifier = Modifier.weight(1f)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold),
                    color = Ink900,
                )
                if (badge != null) {
                    StatusChip(label = badge, tone = StatusTone.Neutral)
                }
            }
            Text(
                text = description,
                style = MaterialTheme.typography.bodySmall,
                color = Ink500,
            )
        }
        // Radio circle (right)
        Box(
            modifier = Modifier
                .size(22.dp)
                .clip(CircleShape)
                .border(
                    width = 2.dp,
                    color = if (selected) BrandGreen else Surface200,
                    shape = CircleShape,
                ),
            contentAlignment = Alignment.Center,
        ) {
            if (selected) {
                Box(
                    modifier = Modifier
                        .size(10.dp)
                        .clip(CircleShape)
                        .background(BrandGreen),
                )
            }
        }
    }
}

// ---- Previews — design-system gallery. Every @Preview under designsystem/
// is also a Roborazzi screenshot test (see app/build.gradle.kts), so a
// variant that is missing here has no visual regression guard.

@Composable
private fun RoleSelectCardGallery() {
    Column(
        modifier = Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("Selected / unselected", style = EsType.Caption)
        RoleSelectCard(
            icon = Icons.Outlined.LocalHospital,
            title = "Hospital admin",
            description = "Book engineers, manage repairs",
            hue = 150,
            selected = true,
            onSelect = {},
        )
        RoleSelectCard(
            icon = Icons.Outlined.Engineering,
            title = "Biomedical engineer",
            description = "Pick up jobs, bid, complete repairs",
            hue = 280,
            selected = false,
            onSelect = {},
        )

        Text("With badge", style = EsType.Caption)
        RoleSelectCard(
            icon = Icons.Outlined.Engineering,
            title = "Biomedical engineer",
            description = "Pick up jobs, bid, complete repairs",
            hue = 280,
            selected = true,
            onSelect = {},
            badge = "Popular",
        )
        RoleSelectCard(
            icon = Icons.Outlined.MedicalServices,
            title = "Parts supplier",
            description = "List parts and fulfil orders",
            hue = 40,
            selected = false,
            onSelect = {},
            badge = "New",
        )

        Text("Disabled", style = EsType.Caption)
        RoleSelectCard(
            icon = Icons.Outlined.Build,
            title = "Manufacturer",
            description = "Receive RFQs and respond to leads",
            hue = 200,
            selected = false,
            onSelect = {},
            enabled = false,
            badge = "Coming soon",
        )
        RoleSelectCard(
            icon = Icons.Outlined.LocalShipping,
            title = "Logistics partner",
            description = "Pick up and deliver shipments",
            hue = 330,
            selected = true,
            onSelect = {},
            enabled = false,
        )

        Text("Long wrapping copy / empty description", style = EsType.Caption)
        RoleSelectCard(
            icon = Icons.Outlined.LocalHospital,
            title = "Hospital biomedical department head (multi-site)",
            description = "Manage ventilators, dialysis machines and imaging equipment across Apollo, Fortis and district hospitals; approve engineer bids from ₹4,500 upwards",
            hue = 150,
            selected = false,
            onSelect = {},
            badge = "Popular",
        )
        RoleSelectCard(
            icon = Icons.Outlined.Engineering,
            title = "Biomedical engineer",
            description = "",
            hue = 280,
            selected = false,
            onSelect = {},
        )
    }
}

@Preview(name = "RoleSelectCard", showBackground = true)
@Composable
private fun RoleSelectCardPreview() {
    EquipSevaTheme(darkTheme = false) { RoleSelectCardGallery() }
}

@Preview(name = "RoleSelectCard large text", showBackground = true, fontScale = 1.3f)
@Composable
private fun RoleSelectCardPreviewLargeText() {
    EquipSevaTheme(darkTheme = false) { RoleSelectCardGallery() }
}
