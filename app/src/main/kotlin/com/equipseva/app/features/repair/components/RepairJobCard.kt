package com.equipseva.app.features.repair.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
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
import com.equipseva.app.designsystem.components.StatusChip
import com.equipseva.app.designsystem.components.StatusTone
import com.equipseva.app.designsystem.theme.Spacing
import java.time.Duration
import java.time.Instant

@Composable
fun RepairJobCard(
    job: RepairJob,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val isEmergency = job.urgency == RepairJobUrgency.Emergency
    Card(
        onClick = onClick,
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(Spacing.md),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
    ) {
        Row(modifier = Modifier.height(IntrinsicSize.Min)) {
            if (isEmergency) {
                Box(
                    modifier = Modifier
                        .width(4.dp)
                        .fillMaxHeight()
                        .background(MaterialTheme.colorScheme.error.copy(alpha = 0.18f)),
                )
            }
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
}

@Composable
private fun ChipRow(job: RepairJob) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(Spacing.xs),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        StatusChip(label = job.status.displayName, tone = job.status.toTone())
        if (job.urgency != RepairJobUrgency.Unknown) {
            StatusChip(label = job.urgency.displayName, tone = job.urgency.toTone())
        }
    }
}

internal fun RepairJobStatus.toTone(): StatusTone = when (this) {
    RepairJobStatus.Requested -> StatusTone.Info
    RepairJobStatus.Assigned -> StatusTone.Warn
    RepairJobStatus.EnRoute, RepairJobStatus.InProgress -> StatusTone.Info
    RepairJobStatus.Completed -> StatusTone.Success
    RepairJobStatus.Cancelled, RepairJobStatus.Disputed -> StatusTone.Danger
    RepairJobStatus.Unknown -> StatusTone.Neutral
}

internal fun RepairJobUrgency.toTone(): StatusTone = when (this) {
    RepairJobUrgency.Emergency -> StatusTone.Danger
    RepairJobUrgency.SameDay -> StatusTone.Warn
    RepairJobUrgency.Scheduled -> StatusTone.Info
    RepairJobUrgency.Unknown -> StatusTone.Neutral
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
