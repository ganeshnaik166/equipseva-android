package com.equipseva.app.features.repair.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Warning
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.designsystem.theme.SevaWarning50
import com.equipseva.app.designsystem.theme.SevaWarning500
import com.equipseva.app.designsystem.theme.SevaWarning700

/**
 * r785 — pre-stuck banner for hospitals on RepairJobDetailScreen.
 *
 * Fires when a hospital's posted job is status='requested', has zero
 * bids, AND was created at least 7 days ago. Mirrors the founder
 * /unmatched-jobs (r661) signal so the hospital can self-serve before
 * the founder has to outreach.
 *
 * Tone-coded warn (not danger) — job is still live + bidable, just
 * isn't getting traction. Suggests two concrete fixes hospitals can try
 * without escalating.
 */
@Composable
fun UnmatchedJobBanner(daysOld: Long) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(SevaWarning50)
            .padding(12.dp),
    ) {
        Row(
            verticalAlignment = Alignment.Top,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Icon(
                imageVector = Icons.Outlined.Warning,
                contentDescription = null,
                tint = SevaWarning500,
                modifier = Modifier.width(18.dp),
            )
            Column(modifier = Modifier.fillMaxWidth()) {
                Text(
                    "No bids yet · $daysOld days posted.",
                    color = SevaWarning700,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    "Try raising the budget or adding more equipment detail. " +
                        "Engineers usually bid faster when scope is concrete.",
                    color = SevaWarning700,
                    fontSize = 11.sp,
                )
            }
        }
    }
}
