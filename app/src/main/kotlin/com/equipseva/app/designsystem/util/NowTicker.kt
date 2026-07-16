package com.equipseva.app.designsystem.util

import androidx.compose.runtime.Composable
import androidx.compose.runtime.State
import androidx.compose.runtime.produceState
import kotlinx.coroutines.delay

/**
 * A wall-clock that recomposes on a fixed cadence (r1429). Emits
 * `System.currentTimeMillis()` immediately, then every [periodMs] while the
 * composable is on screen — enough to drive a live countdown without a
 * per-frame redraw. The coroutine is scoped to the composition, so it stops
 * automatically when the surface leaves the screen.
 */
@Composable
fun rememberNowTicker(periodMs: Long = 30_000L): State<Long> =
    produceState(initialValue = System.currentTimeMillis()) {
        while (true) {
            value = System.currentTimeMillis()
            delay(periodMs)
        }
    }
