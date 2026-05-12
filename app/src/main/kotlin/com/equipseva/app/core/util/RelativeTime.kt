package com.equipseva.app.core.util

import java.time.Duration
import java.time.Instant
import java.time.OffsetDateTime

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
 * Tolerant ISO-8601 overload for raw timestamp strings — `OffsetDateTime.parse`
 * accepts both `Z` (UTC) and offset (`+05:30`) forms that Postgres timestamptz
 * can emit. Returns null on null input or unparseable text so callers can fall
 * back gracefully instead of crashing.
 */
fun relativeLabel(iso: String?, now: Instant = Instant.now()): String? = iso?.let {
    runCatching { relativeLabel(OffsetDateTime.parse(it).toInstant(), now) }.getOrNull()
}

/**
 * Forward/backward deadline label like `"Due in 3d"`, `"Overdue by 45m"`,
 * or `"Due now"` when the delta is inside the last/next minute. Used by AMC
 * visit reminders + escrow disputes where the user needs to see both
 * directions on one widget.
 */
fun countdownLabel(due: Instant, now: Instant = Instant.now()): String {
    val mins = Duration.between(now, due).toMinutes()
    val absMins = Math.abs(mins)
    if (absMins < 1) return "Due now"
    val chunk = when {
        absMins < 60 -> "${absMins}m"
        absMins < 60 * 24 -> "${absMins / 60}h"
        else -> "${absMins / (60 * 24)}d"
    }
    return if (mins > 0) "Due in $chunk" else "Overdue by $chunk"
}
