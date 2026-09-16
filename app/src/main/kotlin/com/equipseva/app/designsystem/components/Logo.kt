package com.equipseva.app.designsystem.components

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.equipseva.app.R
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.designsystem.theme.EsType

// Source PNG is 640×612 (aspect ~1.0458 wide).
private const val LogoAspectRatio = 640f / 612f

/**
 * Full EquipSeva wordmark / brand logo. Renders the rasterized brand asset.
 * Pass [height] to size by visual height; width is derived from the source aspect ratio.
 */
@Composable
fun EquipSevaLogo(
    modifier: Modifier = Modifier,
    height: Dp = 64.dp,
    contentDescription: String? = "EquipSeva",
) {
    Image(
        painter = painterResource(id = R.drawable.logo_full),
        contentDescription = contentDescription,
        contentScale = ContentScale.Fit,
        modifier = modifier
            .height(height)
            .aspectRatio(LogoAspectRatio),
    )
}

/**
 * Square brand stamp variant — for places that need a fixed square footprint
 * (avatars, top bars). Renders the same logo, fit-cropped into a square.
 */
@Composable
fun EquipSevaLogoSquare(
    modifier: Modifier = Modifier,
    size: Dp = 40.dp,
    contentDescription: String? = "EquipSeva",
) {
    Image(
        painter = painterResource(id = R.drawable.logo_full),
        contentDescription = contentDescription,
        contentScale = ContentScale.Fit,
        modifier = modifier.size(size),
    )
}

// ---- Previews — design-system gallery. Every @Preview under designsystem/
// is also a Roborazzi screenshot test (see app/build.gradle.kts), so a
// variant that is missing here has no visual regression guard.

@Composable
private fun LogoGallery() {
    Column(
        modifier = Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(text = "Wordmark — heights 24 / 40 / 64 (default) / 120 dp", style = EsType.Caption)
        EquipSevaLogo(height = 24.dp)
        EquipSevaLogo(height = 40.dp)
        EquipSevaLogo()
        EquipSevaLogo(height = 120.dp, contentDescription = null)

        Text(text = "Square stamp — 24 / 32 / 40 (default) / 56 / 72 dp", style = EsType.Caption)
        Row(
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            EquipSevaLogoSquare(size = 24.dp)
            EquipSevaLogoSquare(size = 32.dp)
            EquipSevaLogoSquare()
            EquipSevaLogoSquare(size = 56.dp)
            EquipSevaLogoSquare(size = 72.dp, contentDescription = null)
        }
    }
}

@Preview(name = "Logo", showBackground = true)
@Composable
private fun LogoPreview() {
    EquipSevaTheme(darkTheme = false) { LogoGallery() }
}

@Preview(name = "Logo large text", showBackground = true, fontScale = 1.3f)
@Composable
private fun LogoPreviewLargeText() {
    EquipSevaTheme(darkTheme = false) { LogoGallery() }
}
