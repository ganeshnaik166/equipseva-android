package com.equipseva.app.core.util

import java.time.Duration
import java.time.Instant

/** Short relative label like "now", "5m", "3h", "2d", "4w". */
fun relativeLabel(instant: Instant, now: Instant = Instant.now()): String {
    val mins = Duration.between(instant, now).toMinutes()
    return when {
        mins < 1 -> "now"
        mins < 60 -> "${mins}m"
        mins < 60 * 24 -> "${mins / 60}h"
        mins < 60 * 24 * 7 -> "${mins / (60 * 24)}d"
        else -> "${mins / (60 * 24 * 7)}w"
    }
}

/**
 * Countdown to a future instant, returning "Due in Xh/Xd" or "Overdue by Xh/Xd"
 * when it's in the past. Returns "Due now" inside the last minute.
 */
fun countdownLabel(instant: Instant, now: Instant = Instant.now()): String {
    val mins = Duration.between(now, instant).toMinutes()
    if (mins in -1..1) return "Due now"
    val overdue = mins < 0
    val absMins = if (overdue) -mins else mins
    val chunk = when {
        absMins < 60 -> "${absMins}m"
        absMins < 60 * 24 -> "${absMins / 60}h"
        absMins < 60 * 24 * 7 -> "${absMins / (60 * 24)}d"
        else -> "${absMins / (60 * 24 * 7)}w"
    }
    return if (overdue) "Overdue by $chunk" else "Due in $chunk"
}
