package com.equipseva.app.designsystem.theme

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

// Semantic elevation tokens — derived from Claude Design tokens.css (--e-1..-4, --e-brand).
// Compose's `shadow(elevation, shape)` modifier takes a single dp; design uses layered
// box-shadows. We approximate by mapping each step to a single elevation that visually
// matches the deepest layer's spread (good enough for Material3 Surface / Card).
object Elevation {
    val none: Dp = 0.dp
    val e1: Dp = 1.dp     // resting cards / list rows
    val e2: Dp = 4.dp     // raised tile, hover state
    val e3: Dp = 12.dp    // snackbars, dropdowns, popovers
    val e4: Dp = 24.dp    // dialogs, modal sheets
    val brand: Dp = 8.dp  // primary CTA shadow

    // Optional ambient color for brand glow (use w/ Modifier.shadow ambientColor=)
    val brandAmbient: Color = Color(0x33054A35)  // rgba(5,74,53, 0.20) per --e-brand
}
