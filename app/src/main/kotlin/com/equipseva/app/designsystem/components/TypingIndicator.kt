package com.equipseva.app.designsystem.components

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.keyframes
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreen50
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.Paper3
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.Spacing

// Three bouncing dots in a chat-bubble container — mirrors the design's typing indicator.
@Composable
fun TypingIndicator(modifier: Modifier = Modifier) {
    val transition = rememberInfiniteTransition(label = "typing")
    val cycle = 1400
    val bubbleShape = RoundedCornerShape(
        topStart = 16.dp,
        topEnd = 16.dp,
        bottomEnd = 16.dp,
        bottomStart = 4.dp,
    )
    Row(
        modifier = modifier
            .clip(bubbleShape)
            .background(BrandGreen50)
            .padding(horizontal = Spacing.md, vertical = Spacing.sm),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        repeat(3) { index ->
            val delay = index * 160
            val offsetY by transition.animateFloat(
                initialValue = 0f,
                targetValue = 0f,
                animationSpec = infiniteRepeatable(
                    animation = keyframes {
                        durationMillis = cycle
                        0f at 0 using LinearEasing
                        0f at delay using LinearEasing
                        -4f at delay + 200 using LinearEasing
                        0f at delay + 400 using LinearEasing
                        0f at cycle using LinearEasing
                    },
                    repeatMode = RepeatMode.Restart,
                ),
                label = "dot$index",
            )
            Box(
                modifier = Modifier
                    .offset(y = offsetY.dp)
                    .size(6.dp)
                    .clip(CircleShape)
                    .background(BrandGreen),
            )
        }
    }
}

// ---- Previews — design-system gallery. Every @Preview under designsystem/
// is also a Roborazzi screenshot test (see app/build.gradle.kts), so a
// variant that is missing here has no visual regression guard.

@Composable
private fun TypingIndicatorGallery() {
    Column(
        modifier = Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(text = "Default", style = EsType.Caption, color = SevaInk500)
        TypingIndicator()

        Text(text = "In a chat thread (engineer replying)", style = EsType.Caption, color = SevaInk500)
        Row(
            modifier = Modifier
                .background(PaperDefault)
                .padding(Spacing.md),
            verticalAlignment = Alignment.Bottom,
            horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            Box(
                modifier = Modifier
                    .size(28.dp)
                    .clip(CircleShape)
                    .background(Paper3),
                contentAlignment = Alignment.Center,
            ) {
                Text(text = "RK", style = EsType.Caption, color = SevaInk500)
            }
            TypingIndicator(modifier = Modifier.padding(bottom = Spacing.xxs))
        }
    }
}

@Preview(name = "TypingIndicator", showBackground = true)
@Composable
private fun TypingIndicatorPreview() {
    EquipSevaTheme(darkTheme = false) { TypingIndicatorGallery() }
}

@Preview(name = "TypingIndicator large text", showBackground = true, fontScale = 1.3f)
@Composable
private fun TypingIndicatorPreviewLargeText() {
    EquipSevaTheme(darkTheme = false) { TypingIndicatorGallery() }
}
