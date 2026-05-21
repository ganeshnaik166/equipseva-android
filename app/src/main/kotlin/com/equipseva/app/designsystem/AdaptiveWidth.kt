package com.equipseva.app.designsystem

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.widthIn
import androidx.compose.runtime.Composable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * Coarse window-width buckets for tablet / foldable / desktop layout fixes.
 * Aligns with Material 3 window size classes but avoids the extra dependency.
 *
 *  - [Compact]   < 600dp  — phones (default branch, unchanged behavior)
 *  - [Medium]    600..839dp — small tablets, foldables unfolded
 *  - [Expanded]  >= 840dp  — large tablets, desktop, ChromeOS landscape
 */
enum class AdaptiveWidth { Compact, Medium, Expanded }

/** The single recommended max content width for body text / list surfaces on wide screens. */
val ContentMaxWidth: Dp = 840.dp

/**
 * Reads the current screen width (dp) and bucketizes it.
 * Recomposes when the device rotates / the window is resized.
 */
@Composable
@ReadOnlyComposable
fun rememberAdaptiveWidth(): AdaptiveWidth =
    adaptiveWidthForDp(LocalConfiguration.current.screenWidthDp)

/**
 * Pure form of [rememberAdaptiveWidth]: bucket an integer dp value
 * into one of the three [AdaptiveWidth] entries. Extracted so the
 * boundary cases (599/600, 839/840) can be unit-tested without
 * standing up a Compose configuration.
 */
internal fun adaptiveWidthForDp(widthDp: Int): AdaptiveWidth = when {
    widthDp < 600 -> AdaptiveWidth.Compact
    widthDp < 840 -> AdaptiveWidth.Medium
    else -> AdaptiveWidth.Expanded
}

/**
 * Caps content width to [ContentMaxWidth] so list rows / forms don't sprawl on tablets.
 * On Compact this is a no-op (`fillMaxWidth`).
 */
@Composable
fun Modifier.maxContentWidth(): Modifier {
    val width = rememberAdaptiveWidth()
    return if (width == AdaptiveWidth.Compact) {
        this.fillMaxWidth()
    } else {
        this
            .fillMaxWidth()
            .widthIn(max = ContentMaxWidth)
    }
}
