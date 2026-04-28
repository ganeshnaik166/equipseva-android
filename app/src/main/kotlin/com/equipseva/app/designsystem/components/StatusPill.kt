package com.equipseva.app.designsystem.components

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.equipseva.app.core.data.repair.RepairJobStatus

// Maps a `RepairJobStatus` to a `Pill` of the matching kind. Single
// source of truth for status colour/text wherever a status badge
// renders (job board, my-bids, active-work, repair detail header).
@Composable
fun StatusPill(status: RepairJobStatus, modifier: Modifier = Modifier) {
    val (text, kind) = when (status) {
        RepairJobStatus.Requested  -> "Requested"  to PillKind.Info
        RepairJobStatus.Assigned   -> "Assigned"   to PillKind.Warn
        RepairJobStatus.EnRoute    -> "En route"   to PillKind.Warn
        RepairJobStatus.InProgress -> "In progress" to PillKind.Lime
        RepairJobStatus.Completed  -> "Completed"  to PillKind.Success
        RepairJobStatus.Cancelled  -> "Cancelled"  to PillKind.Danger
        RepairJobStatus.Disputed   -> "Disputed"   to PillKind.Danger
        RepairJobStatus.Unknown    -> "Unknown"    to PillKind.Neutral
    }
    Pill(text = text, kind = kind, modifier = modifier)
}
