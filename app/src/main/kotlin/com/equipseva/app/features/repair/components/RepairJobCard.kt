package com.equipseva.app.features.repair.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.core.data.repair.RepairJobUrgency
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.designsystem.theme.Spacing
import java.time.Duration
import java.time.Instant

@Composable
fun RepairJobCard(
    job: RepairJob,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Card(
        onClick = onClick,
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(Spacing.md),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
    ) {
        Column(
            modifier = Modifier.padding(Spacing.md),
            verticalArrangement = Arrangement.spacedBy(Spacing.xs),
        ) {
            Text(
                text = job.title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = job.equipmentLabel,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )

            ChipRow(job = job)

            val meta = buildMetaLine(job)
            if (meta.isNotBlank()) {
                Text(
                    text = meta,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun ChipRow(job: RepairJob) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(Spacing.xs),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        StatusChip(job.status)
        if (job.urgency != RepairJobUrgency.Unknown) {
            UrgencyChip(job.urgency)
        }
    }
}

@Composable
private fun StatusChip(status: RepairJobStatus) {
    val (container, content) = when (status) {
        RepairJobStatus.Requested -> MaterialTheme.colorScheme.primaryContainer to MaterialTheme.colorScheme.onPrimaryContainer
        RepairJobStatus.Assigned -> MaterialTheme.colorScheme.secondaryContainer to MaterialTheme.colorScheme.onSecondaryContainer
        else -> MaterialTheme.colorScheme.surfaceVariant to MaterialTheme.colorScheme.onSurfaceVariant
    }
    Chip(text = status.displayName, container = container, content = content)
}

@Composable
private fun UrgencyChip(urgency: RepairJobUrgency) {
    val (container, content) = when (urgency) {
        RepairJobUrgency.Emergency -> MaterialTheme.colorScheme.errorContainer to MaterialTheme.colorScheme.onErrorContainer
        RepairJobUrgency.SameDay -> MaterialTheme.colorScheme.tertiaryContainer to MaterialTheme.colorScheme.onTertiaryContainer
        else -> MaterialTheme.colorScheme.surfaceVariant to MaterialTheme.colorScheme.onSurfaceVariant
    }
    Chip(text = urgency.displayName, container = container, content = content)
}

@Composable
private fun Chip(text: String, container: androidx.compose.ui.graphics.Color, content: androidx.compose.ui.graphics.Color) {
    Surface(
        color = container,
        contentColor = content,
        shape = RoundedCornerShape(Spacing.xs),
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.labelSmall,
            modifier = Modifier.padding(horizontal = Spacing.sm, vertical = Spacing.xxs),
        )
    }
}

private fun buildMetaLine(job: RepairJob): String {
    val pieces = mutableListOf<String>()
    job.estimatedCostRupees?.let { pieces += "Budget ~${formatRupees(it)}" }
    job.createdAtInstant?.let { pieces += "Posted ${formatTimeAgo(it)}" }
    val schedule = listOfNotNull(job.scheduledDate, job.scheduledTimeSlot).joinToString(" ")
    if (schedule.isNotBlank()) pieces += "Scheduled $schedule"
    return pieces.joinToString(" · ")
}

/** Coarse "posted X ago" label. We'd use a real library, but this keeps the feed honest. */
private fun formatTimeAgo(instant: Instant, now: Instant = Instant.now()): String {
    val duration = Duration.between(instant, now)
    val minutes = duration.toMinutes()
    return when {
        minutes < 1L -> "just now"
        minutes < 60L -> "${minutes}m ago"
        minutes < 60L * 24 -> "${minutes / 60}h ago"
        minutes < 60L * 24 * 7 -> "${minutes / (60 * 24)}d ago"
        else -> "${minutes / (60 * 24 * 7)}w ago"
    }
}
