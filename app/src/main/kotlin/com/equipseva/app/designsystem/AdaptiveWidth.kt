package com.equipseva.app.designsystem

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.widthIn
import androidx.compose.runtime.Composable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.ui.Alignment
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
fun rememberAdaptiveWidth(): AdaptiveWidth {
    val widthDp = LocalConfiguration.current.screenWidthDp
    return when {
        widthDp < 600 -> AdaptiveWidth.Compact
        widthDp < 840 -> AdaptiveWidth.Medium
        else -> AdaptiveWidth.Expanded
    }
}

/** Number of columns to render in a tile / grid layout for the current width bucket. */
@Composable
@ReadOnlyComposable
fun adaptiveGridColumns(
    compact: Int = 2,
    medium: Int = 3,
    expanded: Int = 4,
): Int = when (rememberAdaptiveWidth()) {
    AdaptiveWidth.Compact -> compact
    AdaptiveWidth.Medium -> medium
    AdaptiveWidth.Expanded -> expanded
}

/**
 * Caps content width to [ContentMaxWidth] so list rows / forms don't sprawl on tablets.
 * On Compact this is a no-op (`fillMaxWidth`).
 *
 * Apply on the row/item modifier inside a `LazyColumn` whose surface is full-bleed,
 * or wrap a single column in [CenteredContent] when contentPadding is awkward.
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

/**
 * Wrapper that centers its child horizontally and caps the child's width at
 * [ContentMaxWidth] on Medium / Expanded screens. On Compact phones the child
 * fills the available width as before.
 */
@Composable
fun CenteredContent(
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    val width = rememberAdaptiveWidth()
    if (width == AdaptiveWidth.Compact) {
        Box(modifier = modifier.fillMaxWidth(), contentAlignment = Alignment.TopCenter) {
            content()
        }
    } else {
        Box(modifier = modifier.fillMaxWidth(), contentAlignment = Alignment.TopCenter) {
            Box(modifier = Modifier.widthIn(max = ContentMaxWidth)) {
                content()
            }
        }
    }
}
