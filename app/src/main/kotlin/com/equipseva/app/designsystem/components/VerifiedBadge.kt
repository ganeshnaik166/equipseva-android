package com.equipseva.app.designsystem.components

import com.equipseva.app.R
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.designsystem.theme.EsRadius
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700

// Inline KYC trust badge. Small variant fits in a row of metadata; the
// default sits next to the engineer name in profiles.
@Composable
fun VerifiedBadge(modifier: Modifier = Modifier, small: Boolean = false) {
    val iconSize = if (small) 12.dp else 14.dp
    val padH = if (small) 6.dp else 8.dp
    val padV = if (small) 2.dp else 4.dp
    Row(
        modifier = modifier
            .clip(RoundedCornerShape(EsRadius.Pill))
            .background(SevaGreen50)
            .padding(horizontal = padH, vertical = padV),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Icon(
            imageVector = Icons.Filled.Verified,
            contentDescription = null,
            tint = SevaGreen700,
            modifier = Modifier.size(iconSize),
        )
        Text(text = stringResource(R.string.verified_badge_label), style = EsType.Caption, color = SevaGreen700)
    }
}

// ---- Previews — design-system gallery. Every @Preview under designsystem/
// is also a Roborazzi screenshot test (see app/build.gradle.kts), so a
// variant that is missing here has no visual regression guard.

@Composable
private fun VerifiedBadgeGallery() {
    Column(
        modifier = Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(text = "Rajesh Kumar", style = EsType.Body)
            VerifiedBadge()
        }
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(text = "Apollo Hospitals, Chennai · 4.8 ★", style = EsType.Caption)
            VerifiedBadge(small = true)
        }
    }
}

@Preview(name = "VerifiedBadge", showBackground = true)
@Composable
private fun VerifiedBadgePreview() {
    EquipSevaTheme(darkTheme = false) { VerifiedBadgeGallery() }
}

@Preview(name = "VerifiedBadge large text", showBackground = true, fontScale = 1.3f)
@Composable
private fun VerifiedBadgePreviewLargeText() {
    EquipSevaTheme(darkTheme = false) { VerifiedBadgeGallery() }
}
