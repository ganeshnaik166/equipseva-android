package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color

// Light surface gradient — mirrors tokens.css `.bg-premium`:
//   linear-gradient(180deg, #F4F8F5, #E9F1EC)
// + radial(at 20% 10%, #EEF6F1 -> transparent 50%)
// + radial(at 85% 90%, #DCE9E1 -> transparent 55%)
private val PremiumBaseTop = Color(0xFFF4F8F5)
private val PremiumBaseBottom = Color(0xFFE9F1EC)
private val PremiumGlowTop = Color(0xFFEEF6F1)
private val PremiumGlowBottom = Color(0xFFDCE9E1)

// Dark variant mirrors `.bg-premium-dark`:
//   linear-gradient(180deg, #054A35, #022418) + white radial wash
private val PremiumDarkTop = Color(0xFF054A35)
private val PremiumDarkBottom = Color(0xFF022418)
private val PremiumDarkGlowA = Color(0x1FFFFFFF)  // rgba(255,255,255, 0.12)
private val PremiumDarkGlowB = Color(0x0FFFFFFF)  // rgba(255,255,255, 0.06)

/** Layered light surface used on Welcome / Earnings / hospital home hero areas. */
@Composable
fun PremiumGradientSurface(
    modifier: Modifier = Modifier,
    content: @Composable BoxScope.() -> Unit,
) {
    Box(
        modifier = modifier
            .background(
                brush = Brush.verticalGradient(
                    colors = listOf(PremiumBaseTop, PremiumBaseBottom),
                ),
            )
            .drawBehind {
                drawRect(
                    brush = Brush.radialGradient(
                        colors = listOf(PremiumGlowTop, Color.Transparent),
                        center = Offset(size.width * 0.20f, size.height * 0.10f),
                        radius = maxOf(size.width, size.height) * 0.50f,
                    ),
                )
                drawRect(
                    brush = Brush.radialGradient(
                        colors = listOf(PremiumGlowBottom, Color.Transparent),
                        center = Offset(size.width * 0.85f, size.height * 0.90f),
                        radius = maxOf(size.width, size.height) * 0.55f,
                    ),
                )
            },
        content = content,
    )
}

/** Dark variant — used in earnings hero card + sign-in bottom-sheet pane. */
@Composable
fun PremiumGradientSurfaceDark(
    modifier: Modifier = Modifier,
    content: @Composable BoxScope.() -> Unit,
) {
    Box(
        modifier = modifier
            .background(
                brush = Brush.verticalGradient(
                    colors = listOf(PremiumDarkTop, PremiumDarkBottom),
                ),
            )
            .drawBehind {
                drawRect(
                    brush = Brush.radialGradient(
                        colors = listOf(PremiumDarkGlowA, Color.Transparent),
                        center = Offset(size.width * 0.20f, 0f),
                        radius = maxOf(size.width, size.height) * 0.50f,
                    ),
                )
                drawRect(
                    brush = Brush.radialGradient(
                        colors = listOf(PremiumDarkGlowB, Color.Transparent),
                        center = Offset(size.width, size.height),
                        radius = maxOf(size.width, size.height) * 0.50f,
                    ),
                )
            },
        content = content,
    )
}

