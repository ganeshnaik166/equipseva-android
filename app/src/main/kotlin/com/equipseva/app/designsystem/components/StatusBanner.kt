package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.CurrencyRupee
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreen50
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.designsystem.theme.ErrorBg
import com.equipseva.app.designsystem.theme.ErrorRed
import com.equipseva.app.designsystem.theme.Info
import com.equipseva.app.designsystem.theme.InfoBg
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Success
import com.equipseva.app.designsystem.theme.SuccessBg
import com.equipseva.app.designsystem.theme.Warning
import com.equipseva.app.designsystem.theme.WarningBg

enum class StatusBannerTone { Info, Success, Warn, Danger, Brand }

// Color-coded inline banner. Leading icon + title + optional message + optional trailing action.
@Composable
fun StatusBanner(
    title: String,
    modifier: Modifier = Modifier,
    message: String? = null,
    tone: StatusBannerTone = StatusBannerTone.Info,
    leadingIcon: ImageVector? = null,
    action: (@Composable () -> Unit)? = null,
) {
    val (bg: Color, fg: Color) = when (tone) {
        StatusBannerTone.Info -> InfoBg to Info
        StatusBannerTone.Success -> SuccessBg to Success
        StatusBannerTone.Warn -> WarningBg to Warning
        StatusBannerTone.Danger -> ErrorBg to ErrorRed
        StatusBannerTone.Brand -> BrandGreen50 to BrandGreen
    }
    Row(
        // Round 461: liveRegion announces newly-appearing banners.
        // Danger/Warn use Assertive (interrupt other reads) — these
        // are error states. Info/Success/Brand stay Polite — they're
        // confirmations that can wait their turn.
        modifier = modifier
            .fillMaxWidth()
            .clip(MaterialTheme.shapes.medium)
            .background(bg)
            .padding(horizontal = Spacing.md, vertical = Spacing.sm)
            .semantics {
                liveRegion = when (tone) {
                    StatusBannerTone.Danger, StatusBannerTone.Warn -> LiveRegionMode.Assertive
                    else -> LiveRegionMode.Polite
                }
            },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        if (leadingIcon != null) {
            Icon(
                imageVector = leadingIcon,
                contentDescription = null,
                tint = fg,
                modifier = Modifier.size(24.dp),
            )
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                color = fg,
            )
            if (message != null) {
                Text(
                    text = message,
                    style = MaterialTheme.typography.bodySmall,
                    color = fg.copy(alpha = 0.85f),
                )
            }
        }
        if (action != null) {
            action()
        }
    }
}

// ---- Previews — design-system gallery. Every @Preview under designsystem/
// is also a Roborazzi screenshot test (see app/build.gradle.kts), so a
// variant that is missing here has no visual regression guard.

// Realistic per-tone copy so the gallery reads like the app, not a palette.
private fun statusBannerSample(tone: StatusBannerTone): Triple<String, String, ImageVector> = when (tone) {
    StatusBannerTone.Info -> Triple(
        "Engineer en route",
        "Ramesh Kumar reaches Apollo Hospital, Chennai in about 25 min.",
        Icons.Outlined.Schedule,
    )
    StatusBannerTone.Success -> Triple(
        "Repair completed",
        "Philips IntelliVue MX450 monitor is back in service at ICU bed 7.",
        Icons.Filled.CheckCircle,
    )
    StatusBannerTone.Warn -> Triple(
        "Payment pending",
        "₹4,500 due to Priya Sharma for the GE Voluson P8 probe repair.",
        Icons.Filled.CurrencyRupee,
    )
    StatusBannerTone.Danger -> Triple(
        "KYC rejected",
        "Aadhaar name does not match the PAN on file. Re-upload to keep bidding.",
        Icons.Filled.Error,
    )
    StatusBannerTone.Brand -> Triple(
        "EquipSeva Plus active",
        "Priority dispatch enabled for Manipal Hospital, Bengaluru until 31 Mar 2027.",
        Icons.Filled.Verified,
    )
}

@Composable
private fun StatusBannerGallery() {
    Column(
        modifier = Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        StatusBannerTone.entries.forEach { tone ->
            StatusBanner(title = statusBannerSample(tone).first, tone = tone)
        }
        StatusBannerTone.entries.forEach { tone ->
            val (title, message, icon) = statusBannerSample(tone)
            StatusBanner(title = title, message = message, tone = tone, leadingIcon = icon)
        }
        StatusBanner(
            title = "Invoice #ES-2041 paid",
            tone = StatusBannerTone.Success,
            leadingIcon = Icons.Filled.CheckCircle,
        )
        StatusBanner(
            title = "Bid window closes at 6:00 PM",
            message = "3 engineers have quoted on the Mindray BeneHeart D3 defibrillator job.",
            tone = StatusBannerTone.Info,
        )
        StatusBanner(
            title = "Bid accepted",
            message = "Suresh Nair will visit Fortis Hospital, Mohali tomorrow at 10:00 AM.",
            tone = StatusBannerTone.Success,
            leadingIcon = Icons.Filled.CheckCircle,
            action = { TextButton(onClick = {}) { Text("View") } },
        )
        StatusBanner(
            title = "₹12,800 pending for job #4471",
            tone = StatusBannerTone.Warn,
            action = { TextButton(onClick = {}) { Text("Pay now") } },
        )
        StatusBanner(title = "", tone = StatusBannerTone.Info)
        StatusBanner(
            title = "Ventilator calibration overdue for 3 devices at Manipal Hospital, Bengaluru — schedule a service visit before the next AERB audit",
            message = "Engineer Priya Sharma flagged the Dräger Evita V300 (ICU bed 4), Philips Respironics V60 (HDU) and Hamilton C3 (NICU) as due since 12 Aug. Late calibration may void the AMC contract.",
            tone = StatusBannerTone.Danger,
            leadingIcon = Icons.Filled.Error,
            action = { TextButton(onClick = {}) { Text("Schedule") } },
        )
    }
}

@Preview(name = "StatusBanner", showBackground = true)
@Composable
private fun StatusBannerPreview() {
    EquipSevaTheme(darkTheme = false) { StatusBannerGallery() }
}

@Preview(name = "StatusBanner large text", showBackground = true, fontScale = 1.3f)
@Composable
private fun StatusBannerPreviewLargeText() {
    EquipSevaTheme(darkTheme = false) { StatusBannerGallery() }
}
