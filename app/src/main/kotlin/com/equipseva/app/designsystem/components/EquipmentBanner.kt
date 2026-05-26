package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.Spacing

// Patterned banner shown above repair/order details. Brand gradient + dot pattern bg.
@Composable
fun EquipmentBanner(
    title: String,
    serialOrSubtitle: String,
    icon: ImageVector,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(140.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(
                Brush.linearGradient(
                    colors = listOf(BrandGreen, BrandGreenDark),
                ),
            )
            .drawBehind {
                val dotColor = Color.White.copy(alpha = 0.10f)
                val spacingPx = 18.dp.toPx()
                val radius = 1.5.dp.toPx()
                var y = spacingPx / 2f
                while (y < size.height) {
                    var x = spacingPx / 2f
                    while (x < size.width) {
                        drawCircle(color = dotColor, radius = radius, center = Offset(x, y))
                        x += spacingPx
                    }
                    y += spacingPx
                }
            }
            .padding(Spacing.lg),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .size(64.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(Color.White.copy(alpha = 0.18f)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(36.dp),
                )
            }
            Spacer(Modifier.size(Spacing.md))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleLarge,
                    color = Color.White,
                    maxLines = 2,
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    text = serialOrSubtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = Color.White.copy(alpha = 0.80f),
                    maxLines = 1,
                )
            }
        }
    }
}
