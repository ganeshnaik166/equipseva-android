package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Warning
import com.equipseva.app.designsystem.theme.WarningBg

// One-line warning bar shown when device is offline. Pinned-top style.
@Composable
fun OfflineBanner(
    modifier: Modifier = Modifier,
    message: String = "You're offline — changes will sync when you reconnect.",
) {
    Row(
        // Round 461: liveRegion=Polite so TalkBack announces the
        // banner when it appears on a connectivity drop.
        modifier = modifier
            .fillMaxWidth()
            .background(WarningBg)
            .padding(horizontal = Spacing.md, vertical = Spacing.sm)
            .semantics { liveRegion = LiveRegionMode.Polite },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        Icon(
            imageVector = Icons.Filled.WifiOff,
            contentDescription = null,
            tint = Warning,
            modifier = Modifier.size(18.dp),
        )
        Text(
            text = message,
            style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Medium),
            color = Warning,
            maxLines = 2,
        )
    }
}

// ---- Previews — design-system gallery. Every @Preview under designsystem/
// is also a Roborazzi screenshot test (see app/build.gradle.kts), so a
// variant that is missing here has no visual regression guard.

@Composable
private fun OfflineBannerGallery() {
    Column(
        modifier = Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        OfflineBanner()
        OfflineBanner(message = "No internet. Showing cached repair jobs.")
        OfflineBanner(
            message = "You're offline — the ₹4,500 bid from Rajesh Kumar for the Philips " +
                "HeartStart defibrillator at Apollo Hospitals, Chennai will be sent once you reconnect.",
        )
        Text(text = "Empty message", style = MaterialTheme.typography.labelSmall)
        OfflineBanner(message = "")
    }
}

@Preview(name = "OfflineBanner", showBackground = true)
@Composable
private fun OfflineBannerPreview() {
    EquipSevaTheme(darkTheme = false) { OfflineBannerGallery() }
}

@Preview(name = "OfflineBanner large text", showBackground = true, fontScale = 1.3f)
@Composable
private fun OfflineBannerPreviewLargeText() {
    EquipSevaTheme(darkTheme = false) { OfflineBannerGallery() }
}
