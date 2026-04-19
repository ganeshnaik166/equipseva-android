package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
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
    tone: StatusTone = StatusTone.Neutral,
    icon: ImageVector? = null,
    modifier: Modifier = Modifier,
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
                .defaultMinSize(minHeight = 22.dp)
                .height(22.dp)
                .clip(RoundedCornerShape(50))
                .background(bg)
                .padding(horizontal = 8.dp),
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
