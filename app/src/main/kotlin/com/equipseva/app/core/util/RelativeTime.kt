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
