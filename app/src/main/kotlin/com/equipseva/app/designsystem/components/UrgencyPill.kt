package com.equipseva.app.designsystem.components

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.equipseva.app.core.data.repair.RepairJobUrgency

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
