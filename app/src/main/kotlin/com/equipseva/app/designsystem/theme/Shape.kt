package com.equipseva.app.designsystem.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Shapes
import androidx.compose.ui.unit.dp

// Shape scale follows Claude Design tokens (tokens.css clamps cards/inputs to 8px,
// uses pill 999 for buttons + chips, larger radii for sheets).
//   extraSmall = chips/badges (small inset)
//   small      = inputs / dense surfaces
//   medium     = cards (the design's clamped target)
//   large      = hero / feature surfaces
//   extraLarge = bottom sheets / dialogs
val EquipSevaShapes = Shapes(
    extraSmall = RoundedCornerShape(4.dp),
    small = RoundedCornerShape(8.dp),
    medium = RoundedCornerShape(8.dp),
    large = RoundedCornerShape(12.dp),
    extraLarge = RoundedCornerShape(20.dp),
)
