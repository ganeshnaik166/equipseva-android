package com.equipseva.app.designsystem.theme

import androidx.compose.ui.unit.dp

// EquipSeva v1 radius + shadow tokens, ported from tokens.css.
// Spacing already lives in Spacing.kt — no new keys needed.

object EsRadius {
    val Sm   = 4.dp    // inputs, chips
    val Md   = 8.dp    // buttons, cards
    val Lg   = 12.dp   // hero cards
    val Xl   = 16.dp   // modals
    val Pill = 999.dp  // badges + pill-shaped chips
}

// Shadow tokens map to Compose Modifier.shadow(elevation, shape) calls.
// Compose doesn't expose blur/offset directly, so we approximate the
// design's three card shadows with elevation values that look right
// against Paper backgrounds. ShadowFocus is rendered as a 2-dp solid
// SevaGlow border (Modifier.border) rather than a real shadow.
object EsShadow {
    val Card    = 2.dp
    val CardLg  = 8.dp
    val Pressed = 0.dp
    // ShadowFocus is intentionally omitted — use Modifier.border(2.dp,
    // BorderFocus, shape) at the focused element instead.
}
