package com.equipseva.app.designsystem.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.scale
import com.equipseva.app.designsystem.theme.MotionDuration
import com.equipseva.app.designsystem.theme.MotionEasing

/**
 * Mirrors the design's `.tap` class — scales the element to 0.97 while pressed,
 * springing back on release. Pair with `Modifier.clickable(...)` and pass the
 * same [interactionSource] so the press state is shared.
 */
fun Modifier.tapScale(
    interactionSource: MutableInteractionSource,
    pressedScale: Float = 0.97f,
): Modifier = composed {
    val pressed by interactionSource.collectIsPressedAsState()
    val target = if (pressed) pressedScale else 1f
    val scale by animateFloatAsState(
        targetValue = target,
        animationSpec = tween(durationMillis = MotionDuration.tap, easing = MotionEasing.standard),
        label = "tapScale",
    )
    this.scale(scale)
}

@Composable
fun rememberTapInteractionSource(): MutableInteractionSource =
    remember { MutableInteractionSource() }
