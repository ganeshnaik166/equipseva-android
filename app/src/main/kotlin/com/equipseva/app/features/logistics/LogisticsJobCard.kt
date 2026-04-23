package com.equipseva.app.features.logistics

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.equipseva.app.core.data.logistics.LogisticsJob
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.designsystem.components.PrimaryButton
import com.equipseva.app.designsystem.components.StatusChip
import com.equipseva.app.designsystem.components.StatusTone
import com.equipseva.app.designsystem.theme.Spacing

@Composable
internal fun LogisticsJobCard(
    job: LogisticsJob,
    onAccept: (() -> Unit)? = null,
    acceptLoading: Boolean = false,
    acceptEnabled: Boolean = true,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
    ) {
        Column(
            modifier = Modifier.padding(Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.xs),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = job.jobNumber?.let { "#$it" } ?: "Logistics job",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.weight(1f),
                )
                Row(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    if (job.jobType.isNotBlank()) {
                        StatusChip(
                            label = job.jobType.replace('_', ' ').replaceFirstChar { it.uppercase() },
                            tone = StatusTone.Neutral,
                        )
                    }
                    StatusChip(
                        label = job.status.replaceFirstChar { it.uppercase() },
                        tone = job.status.toTone(),
                    )
                }
            }
            job.equipmentDescription?.takeIf { it.isNotBlank() }?.let {
                Text(
                    text = it,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            val route = listOfNotNull(job.pickupLocationLine, job.deliveryLocationLine).joinToString(" → ")
            if (route.isNotBlank()) {
                Text(
                    text = route,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            val price = job.finalPriceRupees ?: job.quotedPriceRupees
            if (price != null) {
                Text(
                    text = formatRupees(price),
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.primary,
                    fontWeight = FontWeight.Bold,
                )
            }
            job.preferredDateIso?.takeIf { it.isNotBlank() }?.let {
                Text(
                    text = "Preferred ${it.take(10)}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            job.actualPickupAtIso?.takeIf { it.isNotBlank() }?.let {
                Text(
                    text = "Picked up ${it.take(10)}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            job.actualDeliveryAtIso?.takeIf { it.isNotBlank() }?.let {
                Text(
                    text = "Delivered ${it.take(10)}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            job.specialInstructions?.takeIf { it.isNotBlank() }?.let {
                Text(
                    text = it,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 2,
                )
            }
            if (onAccept != null) {
                PrimaryButton(
                    label = "Accept job",
                    loading = acceptLoading,
                    enabled = acceptEnabled && !acceptLoading,
                    onClick = onAccept,
                )
            }
        }
    }
}

internal fun String.toTone(): StatusTone = when (lowercase()) {
    "pending", "quoted" -> StatusTone.Info
    "assigned", "in_transit", "picked_up" -> StatusTone.Warn
    "delivered", "completed" -> StatusTone.Success
    "cancelled", "failed" -> StatusTone.Danger
    else -> StatusTone.Neutral
}
