package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.sizeIn

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.designsystem.theme.EsRadius
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.SevaInk900

// Section title + optional right action link, then content slot.
// Matches `shared.jsx:Section` — padding "20dp top, 16dp horizontal,
// 0 bottom" + 12dp Spacer between title and content. Title 18sp/700.
@Composable
fun EsSection(
    title: String,
    modifier: Modifier = Modifier,
    action: String? = null,
    onAction: (() -> Unit)? = null,
    content: @Composable () -> Unit,
) {
    Column(modifier = modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 16.dp, end = 16.dp, top = 20.dp),
            // Centre, not bottom: the trailing action now reserves the 48 dp
            // interactive minimum, and bottom alignment would drop the title
            // to the foot of that taller row.
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = title,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = (-0.18).sp,
                color = SevaInk900,
            )
            if (action != null && onAction != null) {
                // A bare 13 sp label gave the link a hit area under 20 dp
                // tall. The minimum has to be reserved by the node that
                // receives the tap, so the touch target is the clickable
                // wrapper and the label sits centred inside it — Material's
                // `minimumInteractiveComponentSize` is a LayoutModifierNode,
                // so placing it above a nested clickable reserves the space
                // and leaves the hit area the size of the text.
                Box(
                    modifier = Modifier
                        .sizeIn(
                            minWidth = Spacing.MinTouchTarget,
                            minHeight = Spacing.MinTouchTarget,
                        )
                        // Role.Button so TalkBack announces e.g.
                        // "View all, button" instead of treating the
                        // action label as static text. Common pattern
                        // across the home + repair feeds where each
                        // section has a "See more" trailing action.
                        .clickable(onClick = onAction, role = Role.Button),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = action,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = SevaGreen700,
                        modifier = Modifier.padding(start = 8.dp),
                    )
                }
            }
        }
        Spacer(Modifier.height(12.dp))
        content()
    }
}

// ---- Previews — design-system gallery. Every @Preview under designsystem/
// is also a Roborazzi screenshot test (see app/build.gradle.kts), so a
// variant that is missing here has no visual regression guard.

@Composable
private fun EsSectionGallery() {
    Column(
        modifier = Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        EsSection(title = "Upcoming services") {
            Text(
                text = "Ventilator PM · Apollo Hospitals, Chennai · 18 Sep",
                fontSize = 14.sp,
                color = SevaInk900,
                modifier = Modifier.padding(horizontal = 16.dp),
            )
        }
        EsSection(title = "Open repair jobs", action = "View all", onAction = {}) {
            Text(
                text = "C-Arm image intensifier fault · Fortis, Mohali · ₹4,500 estimate",
                fontSize = 14.sp,
                color = SevaInk900,
                modifier = Modifier.padding(horizontal = 16.dp),
            )
        }
        // An action label with no handler must stay hidden so a dead link
        // never reaches the screen; this row guards that contract.
        EsSection(title = "Nearby engineers", action = "See more", onAction = null) {
            Text(
                text = "Ramesh Iyer · Philips MRI certified · 2.3 km away",
                fontSize = 14.sp,
                color = SevaInk900,
                modifier = Modifier.padding(horizontal = 16.dp),
            )
        }
        EsSection(
            title = "Preventive maintenance schedule for critical-care equipment across all Manipal units",
            action = "Manage",
            onAction = {},
        ) {
            Text(
                text = "12 assets due this week",
                fontSize = 14.sp,
                color = SevaInk900,
                modifier = Modifier.padding(horizontal = 16.dp),
            )
        }
        EsSection(title = "", action = "View all", onAction = {}) {
            Text(
                text = "Empty title with trailing action",
                fontSize = 14.sp,
                color = SevaInk900,
                modifier = Modifier.padding(horizontal = 16.dp),
            )
        }
        EsSection(title = "Tinted section", modifier = Modifier.background(SevaGreen50)) {
            Box(
                Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .height(56.dp)
                    .background(SevaGreen700, RoundedCornerShape(EsRadius.Md)),
            )
        }
    }
}

@Preview(name = "EsSection", showBackground = true)
@Composable
private fun EsSectionPreview() {
    EquipSevaTheme(darkTheme = false) { EsSectionGallery() }
}

@Preview(name = "EsSection large text", showBackground = true, fontScale = 1.3f)
@Composable
private fun EsSectionPreviewLargeText() {
    EquipSevaTheme(darkTheme = false) { EsSectionGallery() }
}
