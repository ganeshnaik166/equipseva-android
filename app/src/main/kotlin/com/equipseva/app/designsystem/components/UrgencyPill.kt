package com.equipseva.app.designsystem.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.equipseva.app.core.data.repair.RepairJobUrgency
import com.equipseva.app.designsystem.theme.EquipSevaTheme

@Composable
fun UrgencyPill(urgency: RepairJobUrgency, modifier: Modifier = Modifier) {
    val (text, kind) = urgencyPillTextAndKind(urgency)
    Pill(text = text, kind = kind, modifier = modifier)
}

/**
 * Pure mapping behind [UrgencyPill]. Extracted so the text + colour
 * tone for each [RepairJobUrgency] can be unit-tested.
 */
internal fun urgencyPillTextAndKind(urgency: RepairJobUrgency): Pair<String, PillKind> =
    when (urgency) {
        RepairJobUrgency.Emergency -> "Emergency" to PillKind.Danger
        RepairJobUrgency.SameDay   -> "Same day"  to PillKind.Warn
        RepairJobUrgency.Scheduled -> "Scheduled" to PillKind.Info
        RepairJobUrgency.Unknown   -> "Standard"  to PillKind.Neutral
    }

// ---- Previews — design-system gallery. Every @Preview under designsystem/
// is also a Roborazzi screenshot test (see app/build.gradle.kts), so a
// variant that is missing here has no visual regression guard.

@Composable
private fun UrgencyPillGallery() {
    Column(
        modifier = Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        // Label each row with the enum entry: the Unknown → "Standard"
        // mapping is not obvious from the pill text alone.
        RepairJobUrgency.entries.forEach { urgency ->
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(text = urgency.name, style = MaterialTheme.typography.labelSmall)
                UrgencyPill(urgency = urgency)
            }
        }
        UrgencyPill(
            urgency = RepairJobUrgency.Emergency,
            modifier = Modifier.padding(start = 32.dp),
        )
    }
}

@Preview(name = "UrgencyPill", showBackground = true)
@Composable
private fun UrgencyPillPreview() {
    EquipSevaTheme(darkTheme = false) { UrgencyPillGallery() }
}

@Preview(name = "UrgencyPill large text", showBackground = true, fontScale = 1.3f)
@Composable
private fun UrgencyPillPreviewLargeText() {
    EquipSevaTheme(darkTheme = false) { UrgencyPillGallery() }
}
