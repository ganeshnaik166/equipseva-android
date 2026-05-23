package com.equipseva.app.features.repair.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import com.equipseva.app.core.data.engineers.EngineerDirectoryRepository
import com.equipseva.app.core.util.initialsOf
import com.equipseva.app.designsystem.components.InlineStars
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.SevaGreen500
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInfo50
import com.equipseva.app.designsystem.theme.SevaInfo500
import com.equipseva.app.designsystem.theme.SevaInk400
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900

/**
 * PR-B: gentle nudge shown when the hospital is about to re-book an
 * engineer who is far away (>50km) AND they've already booked them 3+
 * times. Surfaces 2–3 verified local alternatives in a horizontal
 * carousel so the hospital can compare without leaving the flow.
 *
 * The "should we show this?" rule lives in the caller (frequency +
 * distance gate) — this composable just renders when the inputs are
 * present. If [alternatives] is empty we collapse to nothing rather
 * than render an empty carousel.
 */
@Composable
fun RepeatBookingNudge(
    engineerName: String,
    distanceKm: Double,
    alternatives: List<EngineerDirectoryRepository.RecommendedRow>,
    onPickAlternative: (engineerId: String) -> Unit,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
) {
    if (alternatives.isEmpty()) return
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(SevaInfo50)
            .border(1.dp, SevaInfo500.copy(alpha = 0.18f), RoundedCornerShape(14.dp))
            .padding(14.dp),
    ) {
        Row(
            verticalAlignment = Alignment.Top,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Icon(
                imageVector = Icons.Filled.LocationOn,
                contentDescription = null,
                tint = SevaInfo500,
                modifier = Modifier
                    .padding(top = 1.dp)
                    .size(18.dp),
            )
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = repeatBookingNudgeTitle(engineerName, distanceKm),
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = SevaInk900,
                )
                Spacer(Modifier.height(2.dp))
                Text(
                    text = "Try a verified local engineer to cut travel time + cost.",
                    fontSize = 11.sp,
                    color = SevaInk500,
                    lineHeight = 16.sp,
                )
            }
            Box(
                modifier = Modifier
                    .size(24.dp)
                    .clip(CircleShape)
                    .clickable(onClick = onDismiss),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.Outlined.Close,
                    contentDescription = "Dismiss",
                    tint = SevaInk400,
                    modifier = Modifier.size(14.dp),
                )
            }
        }
        Spacer(Modifier.height(10.dp))
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            alternatives.forEach { alt ->
                AlternativeCard(row = alt, onClick = { onPickAlternative(alt.engineerId) })
            }
        }
    }
}

@Composable
private fun AlternativeCard(
    row: EngineerDirectoryRepository.RecommendedRow,
    onClick: () -> Unit,
) {
    Column(
        modifier = Modifier
            .width(180.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(12.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            CarouselAvatar(
                initials = initialsOf(row.fullName),
                avatarUrl = row.avatarUrl,
                size = 36,
            )
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = row.fullName,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = SevaInk900,
                    maxLines = 1,
                )
                val locLine = engineerCardLocationLine(row.city, row.distanceKm)
                if (locLine != null) {
                    Text(
                        text = locLine,
                        fontSize = 10.sp,
                        color = SevaInk500,
                        maxLines = 1,
                    )
                }
            }
        }
        Spacer(Modifier.height(6.dp))
        InlineStars(rating = row.ratingAvg, count = row.totalJobs, small = true)
    }
}

@Composable
internal fun CarouselAvatar(initials: String, avatarUrl: String?, size: Int) {
    Box(
        modifier = Modifier
            .size(size.dp)
            .clip(CircleShape)
            .background(Brush.linearGradient(listOf(SevaGreen700, SevaGreen500))),
        contentAlignment = Alignment.Center,
    ) {
        if (!avatarUrl.isNullOrBlank()) {
            AsyncImage(
                model = avatarUrl,
                contentDescription = null,
                modifier = Modifier.size(size.dp).clip(CircleShape),
                contentScale = androidx.compose.ui.layout.ContentScale.Crop,
            )
        } else {
            Text(
                text = initials,
                color = Color.White,
                fontWeight = FontWeight.SemiBold,
                fontSize = (size * 0.36f).sp,
            )
        }
    }
}

/**
 * Compose the city · distance line under an engineer's name on the
 * RepeatBookingNudge alternative card / HomeHub recommended card.
 *
 *   * Both present → "Bengaluru · 3.2km"
 *   * Only city → "Bengaluru"
 *   * Only distance → "3.2km"
 *   * Both null → null (caller hides the row)
 *
 * Returns null on the all-empty case so the caller doesn't render
 * an empty Text() / extra Spacer.
 *
 * Distance is formatted under Locale.US to keep the decimal as "3.2"
 * not "3,2" on Hindi-locale devices.
 */
internal fun engineerCardLocationLine(city: String?, distanceKm: Double?): String? {
    val parts = listOfNotNull(
        city?.takeIf { it.isNotBlank() },
        distanceKm?.let { "${"%.1f".format(java.util.Locale.US, it)}km" },
    )
    return if (parts.isEmpty()) null else parts.joinToString(" · ")
}

/**
 * Title on the repeat-booking nudge banner.
 *
 * Format: "$engineerName is X.Y km away"
 *
 * Critical pin: Locale.US on the %.1f format — hi-IN would render
 * "Asha Rao is 3,2 km away" with comma-decimal that mis-reads as
 * "3 to 2 km" or a list.
 *
 * Pin the "is N km away" form — frames the engineer as the subject
 * (which is correct because the banner is suggesting alternatives
 * BECAUSE this engineer is far). A refactor to "Engineer X · Y km
 * away" would lose the subject-verb sentence shape.
 *
 * Pin %.1f one decimal — distinct from the engineerCardLocationLine
 * which uses %.1f km (compact "Nkm" form). The nudge banner is more
 * descriptive ("is X.Y km away") so the spacing differs.
 */
internal fun repeatBookingNudgeTitle(engineerName: String, distanceKm: Double): String =
    "$engineerName is ${"%.1f".format(java.util.Locale.US, distanceKm)} km away"
