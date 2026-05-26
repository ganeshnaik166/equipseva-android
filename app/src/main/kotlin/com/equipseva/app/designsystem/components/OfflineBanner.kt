package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
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
        modifier = modifier
            .fillMaxWidth()
            .background(WarningBg)
            .padding(horizontal = Spacing.md, vertical = Spacing.sm),
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
