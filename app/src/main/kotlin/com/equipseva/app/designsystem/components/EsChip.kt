package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.designsystem.theme.EsRadius
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.BorderDefault

// Toggle pill used for filters, specializations, brands, urgency picker.
// Active = filled green-50 + green-700 text; inactive = paper bg + ink-700.
//
// Accessibility: every chip carries a contentDescription so TalkBack
// reads "<label>, selected" or "<label>" instead of just the label
// — without this every filter pill was an unlabeled tap target.
@Composable
fun EsChip(
    text: String,
    modifier: Modifier = Modifier,
    active: Boolean = false,
    onClick: (() -> Unit)? = null,
    leading: (@Composable () -> Unit)? = null,
    contentDescription: String? = null,
) {
    val bg = if (active) SevaGreen50 else PaperDefault
    val border = if (active) SevaGreen700 else BorderDefault
    val fg = if (active) SevaGreen700 else SevaInk700
    val a11yLabel = contentDescription ?: text
    Row(
        modifier = modifier
            .clip(RoundedCornerShape(EsRadius.Pill))
            .background(bg)
            .border(1.dp, border, RoundedCornerShape(EsRadius.Pill))
            // Role.Button announces the verb to TalkBack
            // ("double-tap to activate"); the .semantics block below
            // adds the selected-state hint so the full announcement
            // is "<label>, selected, button" or "<label>, button"
            // depending on `active`. Without the role, TalkBack falls
            // back to the generic clickable announcement and users
            // can't tell EsChip apart from a passive label.
            .let { if (onClick != null) it.clickable(onClick = onClick, role = Role.Button) else it }
            .semantics {
                this.contentDescription = a11yLabel
                this.selected = active
            }
            .padding(horizontal = 12.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        if (leading != null) {
            Box(modifier = Modifier.size(14.dp), contentAlignment = Alignment.Center) { leading() }
        }
        Text(text = text, style = EsType.Label, color = fg)
    }
}

// ---- Previews — design-system gallery. Every @Preview under designsystem/
// is also a Roborazzi screenshot test (see app/build.gradle.kts), so a
// variant that is missing here has no visual regression guard.

@Composable
private fun EsChipGallery() {
    Column(
        modifier = Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(text = "Passive label (no onClick)", style = EsType.Caption, color = SevaInk500)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            EsChip(text = "Ventilator")
            EsChip(text = "Ventilator", active = true)
        }

        Text(text = "Tappable filter", style = EsType.Caption, color = SevaInk500)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            EsChip(text = "Siemens", onClick = {})
            EsChip(text = "Philips", active = true, onClick = {})
            EsChip(text = "GE Healthcare", onClick = {})
        }

        Text(text = "Leading slot", style = EsType.Caption, color = SevaInk500)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            EsChip(
                text = "Urgent",
                onClick = {},
                leading = { Box(Modifier.size(8.dp).background(SevaDanger500, CircleShape)) },
            )
            EsChip(
                text = "Verified engineer",
                active = true,
                onClick = {},
                leading = {
                    Icon(
                        imageVector = Icons.Filled.Check,
                        contentDescription = null,
                        tint = SevaGreen700,
                        modifier = Modifier.size(14.dp),
                    )
                },
            )
        }

        Text(text = "Custom contentDescription", style = EsType.Caption, color = SevaInk500)
        EsChip(
            text = "₹4,500",
            active = true,
            onClick = {},
            contentDescription = "Budget up to 4,500 rupees",
        )

        Text(text = "Edge cases", style = EsType.Caption, color = SevaInk500)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            EsChip(text = "")
            EsChip(text = "", active = true, onClick = {})
        }
        EsChip(
            text = "Apollo Hospitals Jubilee Hills — Radiology Department, Hyderabad, Telangana 500033",
            onClick = {},
        )
        EsChip(
            text = "Dr. Ramesh Iyer, Senior Biomedical Engineer — CT & MRI service specialist",
            active = true,
            onClick = {},
        )
    }
}

@Preview(name = "EsChip", showBackground = true)
@Composable
private fun EsChipPreview() {
    EquipSevaTheme(darkTheme = false) { EsChipGallery() }
}

@Preview(name = "EsChip large text", showBackground = true, fontScale = 1.3f)
@Composable
private fun EsChipPreviewLargeText() {
    EquipSevaTheme(darkTheme = false) { EsChipGallery() }
}
