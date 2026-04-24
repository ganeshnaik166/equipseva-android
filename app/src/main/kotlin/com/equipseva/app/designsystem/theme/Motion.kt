package com.equipseva.app.designsystem.theme

import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.Easing

// Motion tokens — from Claude Design tokens.css (--ease-out, --ease-io) + chat keyframes.
// Use these for `tween(durationMs = MotionDuration.medium, easing = MotionEasing.standard)`.
object MotionEasing {
    // --ease-out: cubic-bezier(0.22, 1, 0.36, 1) — primary easing for entries / taps
    val standard: Easing = CubicBezierEasing(0.22f, 1f, 0.36f, 1f)

    // --ease-io: cubic-bezier(0.65, 0, 0.35, 1) — symmetric for cross-fades / shared element
    val emphasized: Easing = CubicBezierEasing(0.65f, 0f, 0.35f, 1f)
}

object MotionDuration {
    // Tap press scale (.97) — 180ms
    const val tap: Int = 180

    // Hover/press transition target — 220ms (button ripple opacity)
    const val short: Int = 220

    // Screen enter (translateY 6px + opacity) — 320ms
    const val medium: Int = 320

    // List item stagger — 420ms
    const val long: Int = 420

    // Live-pulse ring (used for live-status dots) — 1800ms loop
    const val pulseLoop: Int = 1800
}
