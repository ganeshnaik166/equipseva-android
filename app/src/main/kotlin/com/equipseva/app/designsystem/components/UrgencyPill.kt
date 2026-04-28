package com.equipseva.app.designsystem.components

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.equipseva.app.core.data.repair.RepairJobUrgency

@Composable
fun UrgencyPill(urgency: RepairJobUrgency, modifier: Modifier = Modifier) {
    val (text, kind) = when (urgency) {
        RepairJobUrgency.Emergency -> "Emergency" to PillKind.Danger
        RepairJobUrgency.SameDay   -> "Same day"  to PillKind.Warn
        RepairJobUrgency.Scheduled -> "Scheduled" to PillKind.Info
        RepairJobUrgency.Unknown   -> "Standard"  to PillKind.Neutral
    }
    Pill(text = text, kind = kind, modifier = modifier)
}
