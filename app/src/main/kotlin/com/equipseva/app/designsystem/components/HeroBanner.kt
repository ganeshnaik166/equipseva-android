package com.equipseva.app.designsystem.components

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import com.equipseva.app.R
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreenDark

@Composable
fun HeroBanner(
    headline: String,
    modifier: Modifier = Modifier,
    eyebrow: String? = null,
    subline: String? = null,
    trailing: @Composable (BoxScope.() -> Unit)? = null,
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .clip(MaterialTheme.shapes.large)
            .background(
                Brush.linearGradient(
                    colors = listOf(BrandGreen, BrandGreenDark),
                    start = Offset(0f, 0f),
                    end = Offset(Float.POSITIVE_INFINITY, Float.POSITIVE_INFINITY),
                ),
            )
            .drawBehind {
                val topCircleRadius = 90.dp.toPx()
                drawCircle(
                    color = Color.White.copy(alpha = 0.08f),
                    radius = topCircleRadius,
                    center = Offset(size.width - 30.dp.toPx(), -30.dp.toPx()),
                )
                val bottomCircleRadius = 60.dp.toPx()
                drawCircle(
                    color = Color.White.copy(alpha = 0.05f),
                    radius = bottomCircleRadius,
                    center = Offset(size.width - 80.dp.toPx(), size.height + 20.dp.toPx()),
                )
            }
            .padding(20.dp),
    ) {
        Image(
            painter = painterResource(R.drawable.ic_logo_mark),
            contentDescription = null,
            alpha = 0.18f,
            modifier = Modifier
                .size(160.dp)
                .align(Alignment.BottomEnd),
        )
        Column(modifier = Modifier.fillMaxWidth()) {
            if (eyebrow != null) {
                Text(
                    text = eyebrow,
                    style = MaterialTheme.typography.labelMedium,
                    color = Color.White.copy(alpha = 0.85f),
                )
                Spacer(Modifier.height(4.dp))
            }
            Text(
                text = headline,
                style = MaterialTheme.typography.headlineMedium,
                color = Color.White,
            )
            if (subline != null) {
                Spacer(Modifier.height(6.dp))
                Text(
                    text = subline,
                    style = MaterialTheme.typography.bodyMedium,
                    color = Color.White.copy(alpha = 0.88f),
                )
            }
            if (trailing != null) {
                Spacer(Modifier.height(16.dp))
                Box { trailing() }
            }
        }
    }
}
