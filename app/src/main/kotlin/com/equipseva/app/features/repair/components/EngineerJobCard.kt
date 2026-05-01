package com.equipseva.app.features.repair.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobUrgency
import com.equipseva.app.core.util.relativeLabel
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.components.StatusPill
import com.equipseva.app.designsystem.components.UrgencyPill
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.SevaInk400
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk600
import com.equipseva.app.designsystem.theme.SevaInk900

/**
 * JobCard variant matching `screens-engineer.jsx:JobCard` (lines 6-30).
 * White card, 12dp radius, 1dp border, 14dp padding. Top row = equipment +
 * site/dist/city + UrgencyPill; middle = issue text; bottom row separated by
 * a hairline divider = scheduled (with calendar icon) + bid count + posted.
 *
 * `showStatus = true` swaps the urgency pill for a StatusPill — this is the
 * "Active work" variant per the design source (line 209).
 */
@Composable
fun EngineerJobCard(
    job: RepairJob,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    showStatus: Boolean = false,
    bidsCount: Int = 0,
    distanceKm: Double? = null,
) {
    val shape = RoundedCornerShape(12.dp)
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(shape)
            .background(Color.White)
            .border(1.dp, BorderDefault, shape)
            .clickable(onClick = onClick)
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        // Top row — equipment + site/dist/city + (urgency or status) pill.
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.Top,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = job.equipmentLabel,
                    style = EsType.Body.copy(fontWeight = FontWeight.SemiBold),
                    color = SevaInk900,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                val siteLine = buildString {
                    val parts = mutableListOf<String>()
                    if (!job.siteLocation.isNullOrBlank()) parts += job.siteLocation
                    if (distanceKm != null && distanceKm > 0.0) {
                        // Round to 1 decimal so we don't render `12.345 km`.
                        val rounded = (distanceKm * 10.0).toInt() / 10.0
                        parts += "$rounded km"
                    }
                    append(parts.joinToString(" · "))
                }
                if (siteLine.isNotBlank()) {
                    Text(
                        text = siteLine,
                        style = EsType.Caption,
                        color = SevaInk500,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.padding(top = 2.dp),
                    )
                }
            }
            if (showStatus) {
                StatusPill(status = job.status)
            } else if (job.urgency != RepairJobUrgency.Unknown) {
                UrgencyPill(urgency = job.urgency)
            } else {
                // Spec always shows a pill on the top-right; fall back to a
                // neutral "Standard" pill so the layout stays consistent.
                Pill(text = "Standard", kind = PillKind.Neutral)
            }
        }

        // Middle — issue text.
        if (job.issueDescription.isNotBlank()) {
            Text(
                text = job.issueDescription,
                style = EsType.Caption.copy(fontSize = 12.sp, lineHeight = (12 * 1.4f).sp),
                color = SevaInk600,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(end = 4.dp),
            )
        }

        // Hairline divider above the meta-row.
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(1.dp)
                .background(BorderDefault),
        )

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 0.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // Scheduled + calendar icon.
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Icon(
                    imageVector = Icons.Outlined.CalendarMonth,
                    contentDescription = null,
                    tint = SevaInk400,
                    modifier = Modifier.size(12.dp),
                )
                val scheduledText = listOfNotNull(
                    job.scheduledDate?.takeIf { it.isNotBlank() },
                    job.scheduledTimeSlot?.takeIf { it.isNotBlank() },
                ).joinToString(" ").ifBlank { "Flexible" }
                Text(
                    text = scheduledText,
                    style = EsType.Caption.copy(fontSize = 11.sp),
                    color = SevaInk500,
                )
            }
            // Optional bids count + posted relative time.
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                if (bidsCount > 0) {
                    Text(
                        text = "$bidsCount bids · ",
                        style = EsType.Caption.copy(fontSize = 11.sp),
                        color = SevaInk500,
                    )
                }
                val postedText = job.createdAtInstant?.let { "${relativeLabel(it)} ago" } ?: "Just now"
                Text(
                    text = postedText,
                    style = EsType.Caption.copy(fontSize = 11.sp),
                    color = SevaInk500,
                )
            }
        }
    }
}
