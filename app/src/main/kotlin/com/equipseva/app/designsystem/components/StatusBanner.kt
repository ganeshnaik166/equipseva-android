package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreen50
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
        modifier = modifier
            .fillMaxWidth()
            .clip(MaterialTheme.shapes.medium)
            .background(bg)
            .padding(horizontal = Spacing.md, vertical = Spacing.sm),
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
