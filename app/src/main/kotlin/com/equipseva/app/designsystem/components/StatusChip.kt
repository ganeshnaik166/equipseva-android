package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.ErrorOutline
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material.icons.outlined.WarningAmber
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.designsystem.theme.ErrorBg
import com.equipseva.app.designsystem.theme.ErrorRed
import com.equipseva.app.designsystem.theme.Info
import com.equipseva.app.designsystem.theme.InfoBg
import com.equipseva.app.designsystem.theme.Success
import com.equipseva.app.designsystem.theme.SuccessBg
import com.equipseva.app.designsystem.theme.Warning
import com.equipseva.app.designsystem.theme.WarningBg

enum class StatusTone { Neutral, Info, Warn, Success, Danger }

@Composable
fun StatusChip(
    label: String,
    modifier: Modifier = Modifier,
    tone: StatusTone = StatusTone.Neutral,
    icon: ImageVector? = null,
) {
    val scheme = MaterialTheme.colorScheme
    val (bg: Color, fg: Color) = when (tone) {
        StatusTone.Neutral -> scheme.surfaceVariant to scheme.onSurfaceVariant
        StatusTone.Info -> InfoBg to Info
        StatusTone.Warn -> WarningBg to Warning
        StatusTone.Success -> SuccessBg to Success
        StatusTone.Danger -> ErrorBg to ErrorRed
    }
    CompositionLocalProvider(LocalContentColor provides fg) {
        Row(
            modifier = modifier
                // Minimum only: the 11 sp label has a 14 sp line height, so a
                // fixed 22 dp clipped the glyphs from ~1.6x font scale upward.
                .defaultMinSize(minHeight = 22.dp)
                .clip(RoundedCornerShape(50))
                .background(bg)
                .padding(horizontal = 8.dp, vertical = 2.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            if (icon != null) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = fg,
                    modifier = Modifier.size(12.dp),
                )
            }
            Text(
                text = label,
                fontSize = 11.sp,
                lineHeight = 14.sp,
                fontWeight = FontWeight.SemiBold,
                letterSpacing = 0.1.sp,
                color = fg,
            )
        }
    }
}

// ---- Previews — design-system gallery. Every @Preview under designsystem/
// is also a Roborazzi screenshot test (see app/build.gradle.kts), so a
// variant that is missing here has no visual regression guard.

private fun StatusTone.sampleLabel(): String = when (this) {
    StatusTone.Neutral -> "Draft"
    StatusTone.Info -> "Bid placed"
    StatusTone.Warn -> "Awaiting parts"
    StatusTone.Success -> "Repaired"
    StatusTone.Danger -> "Overdue"
}

private fun StatusTone.sampleIcon(): ImageVector = when (this) {
    StatusTone.Neutral -> Icons.Outlined.Schedule
    StatusTone.Info -> Icons.Outlined.Notifications
    StatusTone.Warn -> Icons.Outlined.WarningAmber
    StatusTone.Success -> Icons.Outlined.CheckCircle
    StatusTone.Danger -> Icons.Outlined.ErrorOutline
}

@Composable
private fun StatusChipGallery() {
    Column(
        modifier = Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(text = "Tones", style = MaterialTheme.typography.labelSmall)
        StatusTone.entries.forEach { tone -> StatusChip(label = tone.sampleLabel(), tone = tone) }

        Text(text = "Tones with icon", style = MaterialTheme.typography.labelSmall)
        StatusTone.entries.forEach { tone ->
            StatusChip(label = tone.sampleLabel(), tone = tone, icon = tone.sampleIcon())
        }

        Text(text = "Edge cases", style = MaterialTheme.typography.labelSmall)
        StatusChip(label = "")
        StatusChip(label = "", tone = StatusTone.Success, icon = Icons.Outlined.CheckCircle)
        StatusChip(
            label = "Quote ₹4,500 · Engineer Ravi Kumar",
            tone = StatusTone.Info,
            modifier = Modifier.width(240.dp),
        )
        StatusChip(
            label = "Awaiting spare part approval from Apollo Hospitals Chennai biomedical department",
            tone = StatusTone.Warn,
            icon = Icons.Outlined.WarningAmber,
            modifier = Modifier.width(240.dp),
        )
    }
}

@Preview(name = "StatusChip", showBackground = true)
@Composable
private fun StatusChipPreview() {
    EquipSevaTheme(darkTheme = false) { StatusChipGallery() }
}

@Preview(name = "StatusChip large text", showBackground = true, fontScale = 1.3f)
@Composable
private fun StatusChipPreviewLargeText() {
    EquipSevaTheme(darkTheme = false) { StatusChipGallery() }
}
