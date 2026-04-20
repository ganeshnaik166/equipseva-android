package com.equipseva.app.features.repair.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Air
import androidx.compose.material.icons.outlined.Build
import androidx.compose.material.icons.outlined.MedicalServices
import androidx.compose.material.icons.outlined.MonitorHeart
import androidx.compose.material.icons.outlined.Radar
import androidx.compose.material.icons.outlined.WaterDrop
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.core.data.repair.RepairBid
import com.equipseva.app.core.data.repair.RepairBidStatus
import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.core.data.repair.RepairJobUrgency
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.designsystem.components.GradientTile
import com.equipseva.app.designsystem.components.StatusChip
import com.equipseva.app.designsystem.components.StatusTone
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface200

@Composable
fun RepairJobCard(
    job: RepairJob,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    ownBid: RepairBid? = null,
) {
    val shape = MaterialTheme.shapes.medium
    Box(
        modifier = modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surface, shape)
            .border(1.dp, Surface200, shape)
            .clickable(onClick = onClick)
            .padding(Spacing.md),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(Spacing.md),
            verticalAlignment = Alignment.Top,
        ) {
            val (hue, icon) = iconForEquipment(job)
            GradientTile(icon = icon, hue = hue, size = 52.dp)
            Column(modifier = Modifier.weight(1f)) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Text(
                        text = job.equipmentLabel,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold,
                        color = Ink900,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f, fill = false),
                    )
                    if (job.urgency != RepairJobUrgency.Unknown) {
                        StatusChip(
                            label = job.urgency.displayName,
                            tone = job.urgency.toTone(),
                        )
                    }
                }
                val modelLine = listOfNotNull(job.equipmentBrand, job.equipmentModel).joinToString(" ")
                if (modelLine.isNotBlank() && modelLine != job.equipmentLabel) {
                    Text(
                        text = modelLine,
                        fontSize = 12.sp,
                        color = Ink500,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.padding(top = 2.dp),
                    )
                }
                Row(
                    modifier = Modifier.padding(top = Spacing.sm),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    StatusChip(label = job.status.displayName, tone = job.status.toTone())
                    if (ownBid != null && ownBid.status != RepairBidStatus.Withdrawn) {
                        val tone = when (ownBid.status) {
                            RepairBidStatus.Accepted -> StatusTone.Success
                            RepairBidStatus.Rejected -> StatusTone.Danger
                            RepairBidStatus.Pending -> StatusTone.Info
                            RepairBidStatus.Withdrawn,
                            RepairBidStatus.Unknown -> StatusTone.Neutral
                        }
                        StatusChip(
                            label = "You bid ${formatRupees(ownBid.amountRupees)}",
                            tone = tone,
                        )
                    }
                }
            }
        }
    }
}

internal fun iconForEquipment(job: RepairJob): Pair<Int, ImageVector> {
    val label = (job.equipmentLabel + " " + (job.equipmentBrand ?: "") + " " + (job.equipmentModel ?: "")).lowercase()
    return when {
        "mri" in label || "ct" in label || "x-ray" in label || "xray" in label -> 200 to Icons.Outlined.Radar
        "ultrasound" in label -> 200 to Icons.Outlined.Radar
        "ecg" in label || "ekg" in label -> 40 to Icons.Outlined.MonitorHeart
        "ventilator" in label -> 0 to Icons.Outlined.Air
        "pump" in label || "infusion" in label -> 280 to Icons.Outlined.WaterDrop
        "defibrillator" in label || "defib" in label -> 200 to Icons.Outlined.MonitorHeart
        else -> when (job.equipmentCategory) {
            RepairEquipmentCategory.ImagingRadiology -> 200 to Icons.Outlined.Radar
            RepairEquipmentCategory.PatientMonitoring, RepairEquipmentCategory.Cardiology -> 40 to Icons.Outlined.MonitorHeart
            RepairEquipmentCategory.LifeSupport -> 0 to Icons.Outlined.Air
            RepairEquipmentCategory.Surgical -> 0 to Icons.Outlined.MedicalServices
            else -> 150 to Icons.Outlined.Build
        }
    }
}

internal fun RepairJobStatus.toTone(): StatusTone = when (this) {
    RepairJobStatus.Requested -> StatusTone.Info
    RepairJobStatus.Assigned -> StatusTone.Info
    RepairJobStatus.EnRoute -> StatusTone.Warn
    RepairJobStatus.InProgress -> StatusTone.Warn
    RepairJobStatus.Completed -> StatusTone.Success
    RepairJobStatus.Cancelled, RepairJobStatus.Disputed -> StatusTone.Danger
    RepairJobStatus.Unknown -> StatusTone.Neutral
}

internal fun RepairJobUrgency.toTone(): StatusTone = when (this) {
    RepairJobUrgency.Emergency -> StatusTone.Danger
    RepairJobUrgency.SameDay -> StatusTone.Warn
    RepairJobUrgency.Scheduled -> StatusTone.Success
    RepairJobUrgency.Unknown -> StatusTone.Neutral
}
