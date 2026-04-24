package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface200

// Selectable date+time chip used in Checkout. Stacked date + time-range, pill rounded.
@Composable
fun DeliverySlotTile(
    date: String,
    timeRange: String,
    selected: Boolean,
    onSelect: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val source = rememberTapInteractionSource()
    val shape = RoundedCornerShape(percent = 50)
    val bg = if (selected) BrandGreen else Surface0
    val fgPrimary: Color = if (selected) Color.White else Ink700
    val fgSecondary: Color = if (selected) Color.White.copy(alpha = 0.85f) else Ink500
    Column(
        modifier = modifier
            .clip(shape)
            .background(bg)
            .border(
                width = 1.dp,
                color = if (selected) BrandGreen else Surface200,
                shape = shape,
            )
            .clickable(
                interactionSource = source,
                indication = null,
                onClick = onSelect,
            )
            .tapScale(source)
            .padding(horizontal = Spacing.lg, vertical = Spacing.sm),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = date,
            style = MaterialTheme.typography.bodySmall,
            color = fgSecondary,
        )
        Text(
            text = timeRange,
            style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.SemiBold),
            color = fgPrimary,
        )
    }
}
