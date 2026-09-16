package com.equipseva.app.designsystem.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.scale
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.designsystem.theme.EsRadius
import com.equipseva.app.designsystem.theme.MotionDuration
import com.equipseva.app.designsystem.theme.MotionEasing
import com.equipseva.app.designsystem.theme.Paper2
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.designsystem.theme.Surface0

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

// ---- Previews — design-system gallery. Every @Preview under designsystem/
// is also a Roborazzi screenshot test (see app/build.gradle.kts), so a
// variant that is missing here has no visual regression guard.

@Composable
private fun TapScaleGallery() {
    Column(
        modifier = Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(text = "Default pressedScale (0.97)", style = MaterialTheme.typography.labelSmall)
        val defaultSource = rememberTapInteractionSource()
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(SevaGreen700, RoundedCornerShape(EsRadius.Md))
                .clickable(interactionSource = defaultSource, indication = null, onClick = {})
                .tapScale(defaultSource)
                .padding(16.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = "Book engineer — ₹4,500",
                color = Surface0,
                style = MaterialTheme.typography.bodyLarge,
            )
        }

        Text(
            text = "Stronger press (pressedScale = 0.9) with wrapping copy",
            style = MaterialTheme.typography.labelSmall,
        )
        val strongSource = rememberTapInteractionSource()
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(Paper2, RoundedCornerShape(EsRadius.Md))
                .border(1.dp, BorderDefault, RoundedCornerShape(EsRadius.Md))
                .clickable(interactionSource = strongSource, indication = null, onClick = {})
                .tapScale(strongSource, pressedScale = 0.9f)
                .padding(16.dp),
        ) {
            Text(
                text = "Philips IntelliVue MX450 patient monitor — Apollo Hospitals, Jubilee Hills, " +
                    "Hyderabad. Assigned to Ramesh Iyer, senior biomedical engineer.",
                color = SevaInk900,
                style = MaterialTheme.typography.bodyMedium,
            )
        }

        Text(
            text = "No-op (pressedScale = 1.0) on a compact tile",
            style = MaterialTheme.typography.labelSmall,
        )
        val flatSource = rememberTapInteractionSource()
        Box(
            modifier = Modifier
                .size(72.dp)
                .background(SevaGreen700, RoundedCornerShape(EsRadius.Md))
                .clickable(interactionSource = flatSource, indication = null, onClick = {})
                .tapScale(flatSource, pressedScale = 1f),
            contentAlignment = Alignment.Center,
        ) {
            Text(text = "AMC", color = Surface0, style = MaterialTheme.typography.labelLarge)
        }
    }
}

@Preview(name = "TapScale", showBackground = true)
@Composable
private fun TapScalePreview() {
    EquipSevaTheme(darkTheme = false) { TapScaleGallery() }
}

@Preview(name = "TapScale large text", showBackground = true, fontScale = 1.3f)
@Composable
private fun TapScalePreviewLargeText() {
    EquipSevaTheme(darkTheme = false) { TapScaleGallery() }
}
