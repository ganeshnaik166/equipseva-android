package com.equipseva.app.features.repair.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.core.data.repair.CostRevision
import com.equipseva.app.core.util.formatRupees

/**
 * Hospital-only banner. Appears above the sticky CTA bar on
 * RepairJobDetailScreen whenever a CostRevision is in `proposed`
 * status for this job. Tap → opens [CostRevisionDecisionSheet].
 */
@Composable
fun CostRevisionBanner(
    revision: CostRevision,
    onTap: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(BANNER_BG)
            .border(1.dp, BANNER_BORDER, RoundedCornerShape(10.dp))
            .clickable(onClick = onTap)
            .padding(12.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Icon(
            imageVector = Icons.Outlined.Info,
            contentDescription = null,
            tint = BANNER_INK,
            modifier = Modifier.size(20.dp),
        )
        Column(
            modifier = Modifier.padding(top = 1.dp),
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            Text(
                text = "Engineer requested a revised quote",
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = BANNER_INK,
            )
            Text(
                text = costRevisionBannerSubtitle(
                    revision.originalAmountRupees,
                    revision.revisedAmountRupees,
                ),
                fontSize = 12.sp,
                color = BANNER_INK,
            )
        }
    }
}

// Soft amber palette for "needs your attention" affordance, picked to
// stand out from the existing primary green CTAs without alarming.
private val BANNER_BG = Color(0xFFFFF8E1)
private val BANNER_BORDER = Color(0xFFF5C518)
private val BANNER_INK = Color(0xFF7A4F01)

/**
 * Subtitle copy on the cost-revision banner: "₹original → ₹revised.
 * Tap to review." Extracted so the rupee-grouping + arrow glyph
 * (U+2192 RIGHTWARDS ARROW, not ASCII "->") can be unit-tested
 * without the Compose runtime.
 */
internal fun costRevisionBannerSubtitle(
    originalRupees: Double,
    revisedRupees: Double,
): String =
    "${formatRupees(originalRupees)} → ${formatRupees(revisedRupees)}. Tap to review."
