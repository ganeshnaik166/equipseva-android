package com.equipseva.app.designsystem.components

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.equipseva.app.R

@Composable
fun BrandedPlaceholder(
    modifier: Modifier = Modifier,
    shape: Shape = MaterialTheme.shapes.medium,
    logoSize: Dp = 48.dp,
) {
    Box(
        modifier = modifier
            .clip(shape)
            .background(MaterialTheme.colorScheme.surfaceVariant),
        contentAlignment = Alignment.Center,
    ) {
        Image(
            painter = painterResource(R.drawable.ic_logo_mark),
            contentDescription = null,
            alpha = 0.4f,
            modifier = Modifier.size(logoSize),
        )
    }
}

@Composable
fun BrandedPlaceholderFill(
    modifier: Modifier = Modifier,
    shape: Shape = MaterialTheme.shapes.medium,
    logoSize: Dp = 96.dp,
) {
    Box(
        modifier = modifier
            .clip(shape)
            .background(MaterialTheme.colorScheme.surfaceVariant),
    ) {
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center,
        ) {
            Image(
                painter = painterResource(R.drawable.ic_logo_mark),
                contentDescription = null,
                alpha = 0.35f,
                modifier = Modifier.size(logoSize),
            )
        }
    }
}
