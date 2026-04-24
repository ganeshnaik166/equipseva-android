package com.equipseva.app.designsystem.components

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.equipseva.app.R

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
