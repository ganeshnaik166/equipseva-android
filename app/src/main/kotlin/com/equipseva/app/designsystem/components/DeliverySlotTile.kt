package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface200

// Selectable date+time chip used in Checkout. Stacked date + time-range, pill rounded.
@Composable
fun DeliverySlotTile(
    date: String,
    timeRange: String,
    selected: Boolean,
    onSelect: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val source = rememberTapInteractionSource()
    val shape = RoundedCornerShape(percent = 50)
    val bg = if (selected) BrandGreen else Surface0
    val fgPrimary: Color = if (selected) Color.White else Ink700
    val fgSecondary: Color = if (selected) Color.White.copy(alpha = 0.85f) else Ink500
    Column(
        modifier = modifier
            .clip(shape)
            .background(bg)
            .border(
                width = 1.dp,
                color = if (selected) BrandGreen else Surface200,
                shape = shape,
            )
            // Round 461: selectable + Role.RadioButton — TalkBack now
            // announces slot selection state instead of "Button".
            .selectable(
                selected = selected,
                onClick = onSelect,
                role = androidx.compose.ui.semantics.Role.RadioButton,
                interactionSource = source,
                indication = null,
            )
            .tapScale(source)
            .padding(horizontal = Spacing.lg, vertical = Spacing.sm),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = date,
            style = MaterialTheme.typography.bodySmall,
            color = fgSecondary,
        )
        Text(
            text = timeRange,
            style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.SemiBold),
            color = fgPrimary,
        )
    }
}

// ---- Previews — design-system gallery. Every @Preview under designsystem/
// is also a Roborazzi screenshot test (see app/build.gradle.kts), so a
// variant that is missing here has no visual regression guard.

@Composable
private fun DeliverySlotTileGallery() {
    Column(
        modifier = Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(text = "Unselected / selected", style = MaterialTheme.typography.labelSmall)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            DeliverySlotTile(
                date = "Tue, 17 Sep",
                timeRange = "9:00 AM – 12:00 PM",
                selected = false,
                onSelect = {},
            )
            DeliverySlotTile(
                date = "Wed, 18 Sep",
                timeRange = "2:00 PM – 5:00 PM",
                selected = true,
                onSelect = {},
            )
        }

        Text(text = "Full width", style = MaterialTheme.typography.labelSmall)
        DeliverySlotTile(
            date = "Thu, 19 Sep",
            timeRange = "10:00 AM – 1:00 PM",
            selected = false,
            onSelect = {},
            modifier = Modifier.fillMaxWidth(),
        )
        DeliverySlotTile(
            date = "Thu, 19 Sep",
            timeRange = "10:00 AM – 1:00 PM",
            selected = true,
            onSelect = {},
            modifier = Modifier.fillMaxWidth(),
        )

        Text(text = "Long wrapping text", style = MaterialTheme.typography.labelSmall)
        DeliverySlotTile(
            date = "Saturday, 20 September 2026 (Ganesh Chaturthi holiday, Apollo Hospitals Jubilee Hills)",
            timeRange = "Any time between 8:00 AM and 8:00 PM — engineer Ramesh Kulkarni will call ahead",
            selected = false,
            onSelect = {},
        )
        DeliverySlotTile(
            date = "Saturday, 20 September 2026 (Ganesh Chaturthi holiday, Apollo Hospitals Jubilee Hills)",
            timeRange = "Any time between 8:00 AM and 8:00 PM — engineer Ramesh Kulkarni will call ahead",
            selected = true,
            onSelect = {},
        )

        Text(text = "Empty text", style = MaterialTheme.typography.labelSmall)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            DeliverySlotTile(date = "", timeRange = "", selected = false, onSelect = {})
            DeliverySlotTile(date = "", timeRange = "", selected = true, onSelect = {})
        }
    }
}

@Preview(name = "DeliverySlotTile", showBackground = true)
@Composable
private fun DeliverySlotTilePreview() {
    EquipSevaTheme(darkTheme = false) { DeliverySlotTileGallery() }
}

@Preview(name = "DeliverySlotTile large text", showBackground = true, fontScale = 1.3f)
@Composable
private fun DeliverySlotTilePreviewLargeText() {
    EquipSevaTheme(darkTheme = false) { DeliverySlotTileGallery() }
}
