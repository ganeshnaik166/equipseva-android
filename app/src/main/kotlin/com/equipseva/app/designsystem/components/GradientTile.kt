package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * Pastel icon tile — approximates the design's oklch(0.96 0.022 h) / oklch(0.42 0.10 h)
 * palette via Color.hsl. Hue cheatsheet: green=150, amber=40, blue=200, red=0, purple=280, pink=330.
 */
@Composable
fun GradientTile(
    icon: ImageVector,
    hue: Int = 150,
    modifier: Modifier = Modifier,
    size: Dp = 48.dp,
    iconSize: Dp = size * 0.44f,
) {
    val h = hue.toFloat().coerceIn(0f, 360f)
    val bg = Color.hsl(h, saturation = 0.22f, lightness = 0.94f)
    val fg = Color.hsl(h, saturation = 0.35f, lightness = 0.42f)
    val strokeColor = Color.hsl(h, saturation = 0.30f, lightness = 0.88f)
    Box(
        modifier = modifier
            .size(size)
            .clip(RoundedCornerShape(8.dp))
            .background(bg)
            .border(1.dp, strokeColor, RoundedCornerShape(8.dp)),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = fg,
            modifier = Modifier.size(iconSize),
        )
    }
}

/**
 * Pastel tile that wraps an [EquipmentIllustration] from the design's SVG art set.
 * The illustration occupies ~68% of the tile, matching the React prototype layout.
 */
@Composable
fun GradientTile(
    art: EquipmentArt,
    hue: Int = 150,
    modifier: Modifier = Modifier,
    size: Dp = 48.dp,
) {
    val h = hue.toFloat().coerceIn(0f, 360f)
    val bg = Color.hsl(h, saturation = 0.22f, lightness = 0.94f)
    val strokeColor = Color.hsl(h, saturation = 0.30f, lightness = 0.88f)
    Box(
        modifier = modifier
            .size(size)
            .clip(RoundedCornerShape(8.dp))
            .background(bg)
            .border(1.dp, strokeColor, RoundedCornerShape(8.dp)),
        contentAlignment = Alignment.Center,
    ) {
        EquipmentIllustration(
            art = art,
            hue = hue,
            modifier = Modifier.size(size * 0.68f),
        )
    }
}
