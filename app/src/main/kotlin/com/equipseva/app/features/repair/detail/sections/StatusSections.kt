package com.equipseva.app.features.repair.detail.sections

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Apartment
import androidx.compose.material.icons.outlined.Block
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material.icons.outlined.Shield
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.R
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.designsystem.components.UrgencyPill
import com.equipseva.app.designsystem.components.VerifiedBadge
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.Paper2
import com.equipseva.app.designsystem.theme.SevaDanger50
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaDanger700
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaGreen900
import com.equipseva.app.designsystem.theme.SevaInk400
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.features.repair.StepLabels
import com.equipseva.app.features.repair.StepStatuses
import com.equipseva.app.features.repair.statusStepIndex

// Status-level banners and the status stepper for the repair job detail screen.
// The detail screen used to be a single 3,500+ line file; each section now lives
// in its own file so hierarchy and layout work can happen per section without
// touching the screen shell. Step labels/statuses stay next to statusStepIndex.

@Composable
internal fun TerminalStatusBanner(title: String, subtitle: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(SevaDanger50)
            .border(1.dp, SevaDanger500, RectangleShape)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(
            imageVector = Icons.Outlined.Block,
            contentDescription = null,
            tint = SevaDanger500,
            modifier = Modifier.size(20.dp),
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = SevaDanger700,
            )
            Text(
                text = subtitle,
                fontSize = 11.sp,
                color = SevaInk500,
            )
        }
    }
}

@Composable
internal fun WarrantyBanner() {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(SevaGreen50)
            .border(1.dp, SevaGreen700, RectangleShape)
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(
            imageVector = Icons.Outlined.Shield,
            contentDescription = null,
            tint = SevaGreen700,
            modifier = Modifier.size(20.dp),
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = stringResource(R.string.repair_warranty_title),
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = SevaGreen900,
            )
            Text(
                text = stringResource(R.string.repair_warranty_body),
                fontSize = 11.sp,
                color = SevaInk500,
            )
        }
    }
}

// --- Hospital banner --------------------------------------------------------
@Composable
internal fun HospitalBanner(siteName: String, siteCity: String?, urgency: com.equipseva.app.core.data.repair.RepairJobUrgency) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color.White)
            .border(width = 1.dp, color = BorderDefault, shape = RectangleShape)
            .padding(start = 16.dp, end = 16.dp, top = 12.dp, bottom = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(RoundedCornerShape(8.dp))
                .background(SevaGreen50),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = Icons.Outlined.Apartment,
                contentDescription = null,
                tint = SevaGreen700,
                modifier = Modifier.size(20.dp),
            )
        }
        Column(modifier = Modifier.weight(1f)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                // The name yields width to the badge, not the other way round: an
                // unweighted Text takes its intrinsic width first and a long hospital
                // name left the badge a few pixels, so "Verified" wrapped one letter
                // per line. fill = false keeps short names hugging the badge.
                Text(
                    text = siteName,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = SevaInk900,
                    modifier = Modifier.weight(1f, fill = false),
                )
                VerifiedBadge(small = true)
            }
            if (!siteCity.isNullOrBlank()) {
                Text(
                    text = siteCity,
                    fontSize = 12.sp,
                    color = SevaInk500,
                )
            }
        }
        UrgencyPill(urgency = urgency)
    }
}

@Composable
internal fun StatusStepperRow(currentStatus: RepairJobStatus) {
    val currentIdx = statusStepIndex(currentStatus)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color.White)
            .border(width = 1.dp, color = BorderDefault, shape = RectangleShape)
            .padding(horizontal = 14.dp, vertical = 12.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            StepStatuses.forEachIndexed { i, _ ->
                val done = currentIdx >= 0 && i < currentIdx
                val active = i == currentIdx
                Column(
                    modifier = Modifier.width(56.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    StepDot(done = done, active = active, number = i + 1)
                    Text(
                        text = StepLabels[i],
                        fontSize = 9.sp,
                        fontWeight = if (active) FontWeight.SemiBold else FontWeight.Medium,
                        color = if (active) SevaInk900 else SevaInk400,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(top = 4.dp),
                    )
                }
                if (i < StepStatuses.lastIndex) {
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .padding(bottom = 18.dp)
                            .height(2.dp)
                            .background(if (i < currentIdx) SevaGreen700 else BorderDefault),
                    )
                }
            }
        }
    }
}

@Composable
internal fun StepDot(done: Boolean, active: Boolean, number: Int) {
    val bg = when {
        done -> SevaGreen700
        active -> Color.White
        else -> Paper2
    }
    val borderColor = when {
        done -> SevaGreen700
        active -> SevaGreen700
        else -> BorderDefault
    }
    val borderW = if (active) 2.dp else 1.dp
    Box(
        modifier = Modifier
            .size(22.dp)
            .clip(CircleShape)
            .background(bg)
            .border(borderW, borderColor, CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        when {
            done -> Icon(
                imageVector = Icons.Outlined.Check,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(12.dp),
            )
            else -> Text(
                text = number.toString(),
                fontSize = 10.sp,
                fontWeight = FontWeight.Bold,
                color = if (active) SevaGreen700 else SevaInk400,
            )
        }
    }
}
