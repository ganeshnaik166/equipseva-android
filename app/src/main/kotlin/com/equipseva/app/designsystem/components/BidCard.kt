package com.equipseva.app.designsystem.components

import com.equipseva.app.R
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import java.util.Locale
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreen50
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.designsystem.theme.Info
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.designsystem.theme.Warning

// Single bid row in repair-detail (hospital view). Avatar + name + rating + amount + chips.
@Composable
fun BidCard(
    engineerName: String,
    rating: Float,
    ratingCount: Int,
    amountRupees: Double,
    modifier: Modifier = Modifier,
    etaHours: Int? = null,
    isVerified: Boolean = false,
    isTopMatch: Boolean = false,
    onClick: (() -> Unit)? = null,
) {
    val source = rememberTapInteractionSource()
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(MaterialTheme.shapes.large)
            .background(Surface0)
            .border(1.dp, Surface200, MaterialTheme.shapes.large)
            .let {
                if (onClick != null) {
                    it.clickable(
                        interactionSource = source,
                        indication = null,
                        onClick = onClick,
                    ).tapScale(source)
                } else {
                    it
                }
            }
            .padding(Spacing.md),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(BrandGreen50),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = Icons.Filled.Person,
                contentDescription = null,
                tint = BrandGreen,
                modifier = Modifier.size(24.dp),
            )
        }
        Column(modifier = Modifier.weight(1f)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Text(
                    text = engineerName,
                    style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.SemiBold),
                    color = Ink900,
                    maxLines = 1,
                )
                if (isVerified) {
                    Icon(
                        imageVector = Icons.Filled.Verified,
                        contentDescription = stringResource(R.string.verified_badge_label),
                        tint = Info,
                        modifier = Modifier.size(16.dp),
                    )
                }
            }
            Spacer(Modifier.height(2.dp))
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                Icon(
                    imageVector = Icons.Filled.Star,
                    contentDescription = null,
                    tint = Warning,
                    modifier = Modifier.size(14.dp),
                )
                Text(
                    text = String.format(Locale.ENGLISH, "%.1f", rating),
                    style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.SemiBold),
                    color = Ink700,
                )
                Text(
                    text = stringResource(R.string.bid_card_rating_count_paren, ratingCount),
                    style = MaterialTheme.typography.bodySmall,
                    color = Ink500,
                )
            }
            if (etaHours != null || isTopMatch) {
                Spacer(Modifier.height(Spacing.xs))
                Row(horizontalArrangement = Arrangement.spacedBy(Spacing.xs)) {
                    if (isTopMatch) {
                        StatusChip(label = "Top match", tone = StatusTone.Success)
                    }
                    if (etaHours != null) {
                        StatusChip(label = "ETA ${etaHours}h", tone = StatusTone.Neutral)
                    }
                }
            }
        }
        Text(
            text = "₹" + String.format(Locale.ENGLISH, "%,.0f", amountRupees),
            style = MaterialTheme.typography.titleLarge.copy(
                fontWeight = FontWeight.SemiBold,
            ),
            color = Ink900,
        )
    }
}

// ---- Previews — design-system gallery. Every @Preview under designsystem/
// is also a Roborazzi screenshot test (see app/build.gradle.kts), so a
// variant that is missing here has no visual regression guard.

@Composable
private fun BidCardGallery() {
    Column(
        modifier = Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        BidCard(
            engineerName = "Rajesh Kumar",
            rating = 4.5f,
            ratingCount = 128,
            amountRupees = 4500.0,
        )
        BidCard(
            engineerName = "Suresh Iyer",
            rating = 4.8f,
            ratingCount = 342,
            amountRupees = 6200.0,
            isVerified = true,
        )
        BidCard(
            engineerName = "Mohammed Farhan",
            rating = 4.9f,
            ratingCount = 57,
            amountRupees = 5100.0,
            isTopMatch = true,
        )
        BidCard(
            engineerName = "Anitha Krishnan",
            rating = 4.2f,
            ratingCount = 19,
            amountRupees = 3800.0,
            etaHours = 4,
        )
        BidCard(
            engineerName = "Vikram Nair",
            rating = 5.0f,
            ratingCount = 1,
            amountRupees = 12000.0,
            etaHours = 24,
            isVerified = true,
            isTopMatch = true,
            onClick = {},
        )
        BidCard(
            engineerName = "Deepak Sharma",
            rating = 0.0f,
            ratingCount = 0,
            amountRupees = 850.0,
        )
        BidCard(
            engineerName = "Dr. Priya Venkataraman Subramaniam Biomedical Services",
            rating = 3.7f,
            ratingCount = 1204,
            amountRupees = 125000.0,
            etaHours = 72,
            isVerified = true,
            onClick = {},
        )
        BidCard(
            engineerName = "",
            rating = 4.0f,
            ratingCount = 8,
            amountRupees = 0.0,
        )
    }
}

@Preview(name = "BidCard", showBackground = true)
@Composable
private fun BidCardPreview() {
    EquipSevaTheme(darkTheme = false) { BidCardGallery() }
}

@Preview(name = "BidCard large text", showBackground = true, fontScale = 1.3f)
@Composable
private fun BidCardPreviewLargeText() {
    EquipSevaTheme(darkTheme = false) { BidCardGallery() }
}
