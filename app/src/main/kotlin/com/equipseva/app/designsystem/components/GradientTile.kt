package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Build
import androidx.compose.material.icons.outlined.Engineering
import androidx.compose.material.icons.outlined.LocalHospital
import androidx.compose.material.icons.outlined.LocalShipping
import androidx.compose.material.icons.outlined.MedicalServices
import androidx.compose.material.icons.outlined.MonitorHeart
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.designsystem.theme.EsType

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

// ---- Previews — design-system gallery. Every @Preview under designsystem/
// is also a Roborazzi screenshot test (see app/build.gradle.kts), so a
// variant that is missing here has no visual regression guard.

@Composable
private fun GradientTileGallery() {
    Column(
        modifier = Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(
            "Icon tile hue sweep: green 150, amber 40, blue 200, red 0, purple 280, pink 330",
            style = EsType.Caption,
        )
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            GradientTile(icon = Icons.Outlined.MonitorHeart, hue = 150)
            GradientTile(icon = Icons.Outlined.Build, hue = 40)
            GradientTile(icon = Icons.Outlined.LocalShipping, hue = 200)
            GradientTile(icon = Icons.Outlined.MedicalServices, hue = 0)
            GradientTile(icon = Icons.Outlined.Engineering, hue = 280)
            GradientTile(icon = Icons.Outlined.LocalHospital, hue = 330)
        }

        Text("Icon tile sizes 32 / 48 / 64 dp, default icon ratio", style = EsType.Caption)
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.Bottom,
        ) {
            GradientTile(icon = Icons.Outlined.MonitorHeart, size = 32.dp)
            GradientTile(icon = Icons.Outlined.MonitorHeart)
            GradientTile(icon = Icons.Outlined.MonitorHeart, size = 64.dp)
        }

        Text("Icon tile 48 dp with explicit icon sizes 16 / 32 dp", style = EsType.Caption)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            GradientTile(icon = Icons.Outlined.Build, hue = 40, iconSize = 16.dp)
            GradientTile(icon = Icons.Outlined.Build, hue = 40, iconSize = 32.dp)
        }

        Text("Out-of-range hues -40 and 400 clamp to the red ends", style = EsType.Caption)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            GradientTile(icon = Icons.Outlined.MedicalServices, hue = -40)
            GradientTile(icon = Icons.Outlined.MedicalServices, hue = 400)
        }

        Text("Art tile, all 17 illustrations at default hue 150", style = EsType.Caption)
        EquipmentArt.entries.chunked(6).forEach { rowArts ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                rowArts.forEach { art -> GradientTile(art = art) }
            }
        }

        Text("Art tile hue sweep on MonitorHeart", style = EsType.Caption)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf(150, 40, 200, 0, 280, 330).forEach { hue ->
                GradientTile(art = EquipmentArt.MonitorHeart, hue = hue)
            }
        }

        Text("Art tile sizes 32 / 48 / 64 dp", style = EsType.Caption)
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.Bottom,
        ) {
            GradientTile(art = EquipmentArt.Engineering, size = 32.dp)
            GradientTile(art = EquipmentArt.Engineering)
            GradientTile(art = EquipmentArt.Engineering, size = 64.dp)
        }
    }
}

@Preview(name = "GradientTile", showBackground = true)
@Composable
private fun GradientTilePreview() {
    EquipSevaTheme(darkTheme = false) { GradientTileGallery() }
}

@Preview(name = "GradientTile large text", showBackground = true, fontScale = 1.3f)
@Composable
private fun GradientTilePreviewLargeText() {
    EquipSevaTheme(darkTheme = false) { GradientTileGallery() }
}
