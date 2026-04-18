package com.equipseva.app.designsystem.components

import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.ErrorRed
import com.equipseva.app.designsystem.theme.Info
import com.equipseva.app.designsystem.theme.Success
import com.equipseva.app.designsystem.theme.Warning

enum class StatusTone { Neutral, Info, Warn, Success, Danger }

@Composable
fun StatusChip(
    label: String,
    tone: StatusTone = StatusTone.Neutral,
    modifier: Modifier = Modifier,
) {
    val scheme = MaterialTheme.colorScheme
    val (bg: Color, fg: Color) = when (tone) {
        StatusTone.Neutral -> scheme.surfaceVariant to scheme.onSurfaceVariant
        StatusTone.Info -> Info.copy(alpha = 0.14f) to Info
        StatusTone.Warn -> Warning.copy(alpha = 0.16f) to Warning
        StatusTone.Success -> Success.copy(alpha = 0.16f) to Success
        StatusTone.Danger -> ErrorRed.copy(alpha = 0.14f) to ErrorRed
    }
    Surface(
        modifier = modifier,
        color = bg,
        contentColor = fg,
        shape = MaterialTheme.shapes.small,
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
        )
    }
}
