package com.equipseva.app.features.logistics

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.core.data.logistics.LogisticsJob
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.designsystem.components.EquipmentArt
import com.equipseva.app.designsystem.components.GradientTile
import com.equipseva.app.designsystem.components.PrimaryButton
import com.equipseva.app.designsystem.components.StatusChip
import com.equipseva.app.designsystem.components.StatusTone
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface200

@Composable
internal fun LogisticsJobCard(
    job: LogisticsJob,
    onAccept: (() -> Unit)? = null,
    acceptLoading: Boolean = false,
    acceptEnabled: Boolean = true,
    onMarkInTransit: (() -> Unit)? = null,
    onMarkDelivered: (() -> Unit)? = null,
    loading: Boolean = false,
) {
    // Outlined card per the design system (matches AppCard variant="outlined" in /tmp/eqdesign2).
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(MaterialTheme.shapes.large)
            .background(Surface0)
            .border(1.dp, Surface200, MaterialTheme.shapes.large)
            .padding(Spacing.lg),
        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(Spacing.md),
            verticalAlignment = Alignment.Top,
        ) {
            // Pastel SVG truck thumb — hue 200 (blue) for logistics.
            GradientTile(art = EquipmentArt.LocalShipping, hue = 200, size = 48.dp)
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = job.jobNumber?.let { "#$it" } ?: "Logistics job",
                        fontSize = 14.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Ink900,
                        modifier = Modifier.weight(1f),
                    )
                    StatusChip(
                        label = job.status.replace('_', ' ').replaceFirstChar { it.uppercase() },
                        tone = job.status.toTone(),
                    )
                }
                if (job.jobType.isNotBlank()) {
                    Text(
                        text = job.jobType.replace('_', ' ').replaceFirstChar { it.uppercase() },
                        style = MaterialTheme.typography.labelMedium,
                        color = Ink500,
                    )
                }
            }
        }

        job.equipmentDescription?.takeIf { it.isNotBlank() }?.let {
            Text(
                text = it,
                style = MaterialTheme.typography.bodyMedium,
                color = Ink900,
            )
        }

        val route = listOfNotNull(job.pickupLocationLine, job.deliveryLocationLine).joinToString(" → ")
        if (route.isNotBlank()) {
            Text(
                text = route,
                style = MaterialTheme.typography.bodySmall,
                color = Ink500,
            )
        }

        val price = job.finalPriceRupees ?: job.quotedPriceRupees
        if (price != null) {
            Text(
                text = formatRupees(price),
                style = MaterialTheme.typography.titleMedium,
                color = BrandGreenDark,
                fontWeight = FontWeight.SemiBold,
            )
        }

        val metaParts = buildList {
            job.preferredDateIso?.takeIf { it.isNotBlank() }?.let { add("Preferred ${it.take(10)}") }
            job.actualPickupAtIso?.takeIf { it.isNotBlank() }?.let { add("Picked up ${it.take(10)}") }
            job.actualDeliveryAtIso?.takeIf { it.isNotBlank() }?.let { add("Delivered ${it.take(10)}") }
        }
        if (metaParts.isNotEmpty()) {
            Text(
                text = metaParts.joinToString(" · "),
                style = MaterialTheme.typography.bodySmall,
                color = Ink500,
            )
        }

        job.specialInstructions?.takeIf { it.isNotBlank() }?.let {
            Text(
                text = it,
                style = MaterialTheme.typography.bodySmall,
                color = Ink500,
                maxLines = 2,
            )
        }

        // Lifecycle actions — one at a time based on call site.
        when {
            onAccept != null -> PrimaryButton(
                label = "Accept job",
                loading = acceptLoading,
                enabled = acceptEnabled && !acceptLoading,
                onClick = onAccept,
            )
            onMarkInTransit != null -> PrimaryButton(
                label = "Mark in transit",
                loading = loading,
                enabled = !loading,
                onClick = onMarkInTransit,
            )
            onMarkDelivered != null -> PrimaryButton(
                label = "Mark delivered",
                loading = loading,
                enabled = !loading,
                onClick = onMarkDelivered,
            )
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
