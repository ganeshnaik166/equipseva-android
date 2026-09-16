package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900

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

// ---- Previews — design-system gallery. Every @Preview under designsystem/
// is also a Roborazzi screenshot test (see app/build.gradle.kts), so a
// variant that is missing here has no visual regression guard.

@Composable
private fun PremiumGradientSurfaceGallery() {
    Column(
        modifier = Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(text = "Light — hospital home hero", style = EsType.Caption, color = SevaInk500)
        PremiumGradientSurface(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp)),
        ) {
            Column(modifier = Modifier.padding(20.dp)) {
                Text(text = "APOLLO HOSPITALS, JUBILEE HILLS", style = EsType.Overline, color = SevaGreen700)
                Text(text = "Good morning, Dr. Meera Nair", style = EsType.H3, color = SevaInk900)
                Text(
                    text = "3 service requests open · Engineer Rajesh Kumar en route",
                    style = EsType.Body,
                    color = SevaInk500,
                )
            }
        }

        Text(text = "Light — empty content", style = EsType.Caption, color = SevaInk500)
        PremiumGradientSurface(
            modifier = Modifier
                .fillMaxWidth()
                .height(72.dp),
        ) {}

        Text(text = "Light — long wrapping text", style = EsType.Caption, color = SevaInk500)
        PremiumGradientSurface(modifier = Modifier.fillMaxWidth()) {
            Text(
                text = "Philips IntelliVue MX450 patient monitor at Manipal Hospital, Whitefield — annual maintenance contract renewal due; quoted ₹18,750 by Suresh Menon, senior biomedical engineer",
                modifier = Modifier.padding(16.dp),
                style = EsType.BodySm,
                color = SevaInk900,
            )
        }

        Text(text = "Dark — earnings hero", style = EsType.Caption, color = SevaInk500)
        PremiumGradientSurfaceDark(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp)),
        ) {
            Column(modifier = Modifier.padding(20.dp)) {
                Text(text = "THIS MONTH", style = EsType.Overline, color = Color.White.copy(alpha = 0.70f))
                Text(text = "₹48,500", style = EsType.H3, color = Color.White)
                Text(
                    text = "Paid ₹32,000 · Pending ₹16,500",
                    style = EsType.Body,
                    color = Color.White.copy(alpha = 0.85f),
                )
            }
        }

        Text(text = "Dark — empty content", style = EsType.Caption, color = SevaInk500)
        PremiumGradientSurfaceDark(
            modifier = Modifier
                .fillMaxWidth()
                .height(72.dp),
        ) {}

        Text(text = "Dark — long wrapping text", style = EsType.Caption, color = SevaInk500)
        PremiumGradientSurfaceDark(modifier = Modifier.fillMaxWidth()) {
            Text(
                text = "Sign in to EquipSeva to track repair jobs for GE Voluson E8 ultrasound units across Fortis Hospitals, Bengaluru, and settle invoices like ₹4,500 in one tap",
                modifier = Modifier.padding(16.dp),
                style = EsType.BodySm,
                color = Color.White,
            )
        }

        Text(text = "Square — glow placement at 1:1", style = EsType.Caption, color = SevaInk500)
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            PremiumGradientSurface(modifier = Modifier.size(96.dp)) {
                Text(
                    text = "Light",
                    modifier = Modifier.align(Alignment.Center),
                    style = EsType.Label,
                    color = SevaInk900,
                )
            }
            PremiumGradientSurfaceDark(modifier = Modifier.size(96.dp)) {
                Text(
                    text = "Dark",
                    modifier = Modifier.align(Alignment.Center),
                    style = EsType.Label,
                    color = Color.White,
                )
            }
        }
    }
}

@Preview(name = "PremiumGradientSurface", showBackground = true)
@Composable
private fun PremiumGradientSurfacePreview() {
    EquipSevaTheme(darkTheme = false) { PremiumGradientSurfaceGallery() }
}

@Preview(name = "PremiumGradientSurface large text", showBackground = true, fontScale = 1.3f)
@Composable
private fun PremiumGradientSurfacePreviewLargeText() {
    EquipSevaTheme(darkTheme = false) { PremiumGradientSurfaceGallery() }
}
