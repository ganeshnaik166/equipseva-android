package com.equipseva.app.designsystem.util

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.coroutineScope

/**
 * Silently re-runs [action] every [periodMs] while [enabled] is true and the
 * host is composed (r1430). Used on live boards — e.g. Code Red — so status
 * changes (an engineer accepting, an SLA timing out) surface without a manual
 * pull-to-refresh. The loop is keyed on [enabled], so it starts/stops as the
 * board gains or loses active items; [action] is captured via
 * rememberUpdatedState so the latest reload closure always runs.
 */
@Composable
fun PollingEffect(
    enabled: Boolean,
    periodMs: Long = 30_000L,
    action: () -> Unit,
) {
    val current by rememberUpdatedState(action)
    LaunchedEffect(enabled) {
        if (!enabled) return@LaunchedEffect
        coroutineScope {
            while (isActive) {
                delay(periodMs)
                current()
            }
        }
    }
}
