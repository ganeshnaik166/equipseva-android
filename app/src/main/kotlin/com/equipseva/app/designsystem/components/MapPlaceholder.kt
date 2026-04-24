package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreen50
import com.equipseva.app.designsystem.theme.BrandGreen100
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Spacing

// Map placeholder used when no real map is wired. Faint brand-tinted grid lines + center pin.
@Composable
fun MapPlaceholder(
    modifier: Modifier = Modifier,
    addressLine: String? = null,
) {
    Column(modifier = modifier.fillMaxWidth()) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(16f / 9f)
                .clip(RoundedCornerShape(12.dp))
                .background(BrandGreen50)
                .drawBehind {
                    val step = 24.dp.toPx()
                    val stroke = 1.dp.toPx()
                    val color = BrandGreen100
                    var x = 0f
                    while (x < size.width) {
                        drawLine(
                            color = color,
                            start = Offset(x, 0f),
                            end = Offset(x, size.height),
                            strokeWidth = stroke,
                        )
                        x += step
                    }
                    var y = 0f
                    while (y < size.height) {
                        drawLine(
                            color = color,
                            start = Offset(0f, y),
                            end = Offset(size.width, y),
                            strokeWidth = stroke,
                        )
                        y += step
                    }
                },
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = Icons.Filled.LocationOn,
                contentDescription = null,
                tint = BrandGreen,
                modifier = Modifier.size(40.dp),
            )
        }
        if (addressLine != null) {
            Spacer(Modifier.height(Spacing.sm))
            Text(
                text = addressLine,
                style = MaterialTheme.typography.bodyMedium,
                color = Ink700,
                modifier = Modifier.padding(horizontal = Spacing.xs),
            )
        }
    }
}
