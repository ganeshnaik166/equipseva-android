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
import com.equipseva.app.core.util.relativeLabel
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
                val modelLine = repairJobModelLine(job)
                if (modelLine != null) {
                    Text(
                        text = modelLine,
                        fontSize = 12.sp,
                        color = Ink500,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.padding(top = 2.dp),
                    )
                }
                val schedule = repairJobScheduleLabel(job)
                if (schedule != null) {
                    Text(
                        text = schedule,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Ink900,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.padding(top = 4.dp),
                    )
                }
                job.estimatedCostRupees?.let { budget ->
                    Text(
                        text = "Budget ~ ${formatRupees(budget)}",
                        fontSize = 12.sp,
                        color = Ink500,
                        maxLines = 1,
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
                    job.createdAtInstant?.let { posted ->
                        Text(
                            text = "· ${relativeLabel(posted)} ago",
                            fontSize = 12.sp,
                            color = Ink500,
                        )
                    }
                }
            }
        }
    }
}

/**
 * Pure-Kotlin proxy for icon/hue selection. Keyword sniff over the brand +
 * model + label first, then a fallback by [RepairEquipmentCategory]. The
 * Compose-facing [iconForEquipment] maps this to the actual [ImageVector] —
 * splitting it out keeps the routing rules unit-testable without pulling
 * in Compose for the icon lookup.
 */
internal enum class EquipmentIconKind(val hue: Int) {
    Imaging(200),
    Cardiac(40),
    LifeSupport(0),
    Infusion(280),
    Surgical(0),
    Generic(150),
}

internal fun equipmentIconKind(job: RepairJob): EquipmentIconKind {
    val label = (job.equipmentLabel + " " + (job.equipmentBrand ?: "") + " " + (job.equipmentModel ?: "")).lowercase()
    return when {
        "mri" in label || "ct" in label || "x-ray" in label || "xray" in label -> EquipmentIconKind.Imaging
        "ultrasound" in label -> EquipmentIconKind.Imaging
        "ecg" in label || "ekg" in label -> EquipmentIconKind.Cardiac
        "ventilator" in label -> EquipmentIconKind.LifeSupport
        "pump" in label || "infusion" in label -> EquipmentIconKind.Infusion
        "defibrillator" in label || "defib" in label -> EquipmentIconKind.Cardiac
        else -> when (job.equipmentCategory) {
            RepairEquipmentCategory.ImagingRadiology -> EquipmentIconKind.Imaging
            RepairEquipmentCategory.PatientMonitoring, RepairEquipmentCategory.Cardiology -> EquipmentIconKind.Cardiac
            RepairEquipmentCategory.LifeSupport -> EquipmentIconKind.LifeSupport
            RepairEquipmentCategory.Surgical -> EquipmentIconKind.Surgical
            else -> EquipmentIconKind.Generic
        }
    }
}

internal fun iconForEquipment(job: RepairJob): Pair<Int, ImageVector> {
    val kind = equipmentIconKind(job)
    val icon = when (kind) {
        EquipmentIconKind.Imaging -> Icons.Outlined.Radar
        EquipmentIconKind.Cardiac -> Icons.Outlined.MonitorHeart
        EquipmentIconKind.LifeSupport -> Icons.Outlined.Air
        EquipmentIconKind.Infusion -> Icons.Outlined.WaterDrop
        EquipmentIconKind.Surgical -> Icons.Outlined.MedicalServices
        EquipmentIconKind.Generic -> Icons.Outlined.Build
    }
    return kind.hue to icon
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

internal fun RepairBidStatus.toTone(): StatusTone = when (this) {
    RepairBidStatus.Pending -> StatusTone.Info
    RepairBidStatus.Accepted -> StatusTone.Success
    RepairBidStatus.Rejected -> StatusTone.Danger
    RepairBidStatus.Withdrawn -> StatusTone.Neutral
    RepairBidStatus.Unknown -> StatusTone.Neutral
}

/**
 * Secondary line under the equipment label: "<brand> <model>", but only if
 * it adds information over [RepairJob.equipmentLabel] (which already falls
 * back to brand+model when blank). Returns `null` when there's nothing
 * useful to show, so the composable can skip the row entirely. Mirrors the
 * inline check that lived in the Composable verbatim — the trailing
 * `joinToString(" ")` keeps a leading space if `equipmentBrand` is null
 * because the original code does too.
 */
internal fun repairJobModelLine(job: RepairJob): String? {
    val combined = listOfNotNull(job.equipmentBrand, job.equipmentModel).joinToString(" ")
    if (combined.isBlank()) return null
    if (combined == job.equipmentLabel) return null
    return combined
}

/**
 * "Scheduled <date> <slot>" — built when the joined date + slot has any
 * non-blank text. Returns `null` when there's nothing to show so the
 * composable can skip the row and not render a dangling "Scheduled "
 * label. Behaviour-preserving: matches the inline `joinToString(" ").trim()`
 * pattern, so a blank-but-non-null date still introduces internal
 * whitespace just like the original.
 */
internal fun repairJobScheduleLabel(job: RepairJob): String? {
    val schedule = listOfNotNull(job.scheduledDate, job.scheduledTimeSlot).joinToString(" ").trim()
    if (schedule.isBlank()) return null
    return "Scheduled $schedule"
}
