package com.equipseva.app.designsystem.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.designsystem.theme.EquipSevaTheme

// Maps a `RepairJobStatus` to a `Pill` of the matching kind. Single
// source of truth for status colour/text wherever a status badge
// renders (job board, my-bids, active-work, repair detail header).
@Composable
fun StatusPill(status: RepairJobStatus, modifier: Modifier = Modifier) {
    val (text, kind) = statusPillTextAndKind(status)
    Pill(text = text, kind = kind, modifier = modifier)
}

/**
 * Pure mapping behind [StatusPill]. Extracted so the text + colour
 * tone for each [RepairJobStatus] can be unit-tested without standing
 * up the Compose runtime.
 */
internal fun statusPillTextAndKind(status: RepairJobStatus): Pair<String, PillKind> =
    when (status) {
        RepairJobStatus.Requested  -> "Requested"  to PillKind.Info
        RepairJobStatus.Assigned   -> "Assigned"   to PillKind.Warn
        RepairJobStatus.EnRoute    -> "En route"   to PillKind.Warn
        RepairJobStatus.InProgress -> "In progress" to PillKind.Lime
        RepairJobStatus.Completed  -> "Completed"  to PillKind.Success
        RepairJobStatus.Cancelled  -> "Cancelled"  to PillKind.Danger
        RepairJobStatus.Disputed   -> "Disputed"   to PillKind.Danger
        RepairJobStatus.Unknown    -> "Unknown"    to PillKind.Neutral
    }

// ---- Previews — design-system gallery. Every @Preview under designsystem/
// is also a Roborazzi screenshot test (see app/build.gradle.kts), so a
// variant that is missing here has no visual regression guard.

@Composable
private fun StatusPillGallery() {
    Column(
        modifier = Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        RepairJobStatus.entries.forEach { status -> StatusPill(status = status) }
    }
}

@Preview(name = "StatusPill", showBackground = true)
@Composable
private fun StatusPillPreview() {
    EquipSevaTheme(darkTheme = false) { StatusPillGallery() }
}

@Preview(name = "StatusPill large text", showBackground = true, fontScale = 1.3f)
@Composable
private fun StatusPillPreviewLargeText() {
    EquipSevaTheme(darkTheme = false) { StatusPillGallery() }
}
