package com.equipseva.app.designsystem.theme

import androidx.compose.ui.unit.dp

// Compatibility names for the approved badge / input / card / sheet geometry.

object EsRadius {
    val Sm   = 8.dp    // badges
    val Md   = 16.dp   // inputs
    val Lg   = 24.dp   // cards
    val Xl   = 28.dp   // hero cards, modals
    val Pill = 999.dp  // badges + pill-shaped chips
}

// Shadow tokens map to Compose Modifier.shadow(elevation, shape) calls.
// Compose doesn't expose blur/offset directly, so we approximate the
// design's three card shadows with elevation values that look right
// against Paper backgrounds. ShadowFocus is rendered as a 2-dp solid
// SevaGlow border (Modifier.border) rather than a real shadow.
object EsShadow {
    val Card    = 2.dp
    val CardLg  = 2.dp
    val Pressed = 0.dp
    // ShadowFocus is intentionally omitted — use Modifier.border(2.dp,
    // BorderFocus, shape) at the focused element instead.
}
