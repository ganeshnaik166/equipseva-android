package com.equipseva.app.designsystem.components

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

@Composable
fun ShimmerBox(
    modifier: Modifier = Modifier,
    shape: Shape = MaterialTheme.shapes.medium,
) {
    val base = MaterialTheme.colorScheme.surfaceVariant
    val highlight = MaterialTheme.colorScheme.surface
    val transition = rememberInfiniteTransition(label = "shimmer")
    val progress by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 1400, easing = LinearEasing),
            repeatMode = RepeatMode.Restart,
        ),
        label = "shimmer-progress",
    )
    val width = 600f
    val translate = progress * (width * 2) - width
    val brush = Brush.linearGradient(
        colors = listOf(base, highlight.copy(alpha = 0.55f), base),
        start = Offset(translate, 0f),
        end = Offset(translate + width, 0f),
    )
    Box(
        modifier
            .clip(shape)
            .background(base)
            .drawWithContent {
                drawContent()
                drawRect(brush = brush, blendMode = BlendMode.SrcAtop)
            },
    )
}

@Composable
fun ShimmerLine(
    modifier: Modifier = Modifier,
    width: Dp? = null,
    height: Dp = 14.dp,
) {
    val base = Modifier.height(height)
    val sized = if (width != null) base.width(width) else base.fillMaxWidth()
    ShimmerBox(modifier = modifier.then(sized), shape = RoundedCornerShape(6.dp))
}

@Composable
fun ShimmerListItem(modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
    ) {
        ShimmerBox(
            modifier = Modifier.size(56.dp),
            shape = RoundedCornerShape(10.dp),
        )
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.fillMaxWidth()) {
            ShimmerLine(width = 180.dp, height = 14.dp)
            Spacer(Modifier.height(8.dp))
            ShimmerLine(width = 120.dp, height = 12.dp)
            Spacer(Modifier.height(8.dp))
            ShimmerLine(width = 80.dp, height = 12.dp)
        }
    }
}

/**
 * Generic skeleton loader for list screens. Renders [rows] shimmering list items
 * shaped like an avatar + two text lines. Use as a stand-in for
 * `CircularProgressIndicator` when initial-loading a list with no cached items.
 */
@Composable
fun ListSkeleton(
    modifier: Modifier = Modifier,
    rows: Int = 8,
) {
    Column(modifier = modifier.fillMaxWidth()) {
        repeat(rows) { ShimmerListItem() }
    }
}
