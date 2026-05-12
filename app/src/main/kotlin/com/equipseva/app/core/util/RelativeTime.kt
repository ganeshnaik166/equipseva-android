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
