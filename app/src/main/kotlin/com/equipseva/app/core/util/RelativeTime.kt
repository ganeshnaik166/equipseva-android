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
 * The standalone sub-minute label [relativeLabel] returns. It is a whole
 * phrase, not a quantity like "5m" — which is why every "how long ago"
 * caller needs [relativeAgoLabel] / [relativeAgoPhrase] instead of
 * appending " ago" to [relativeLabel] itself.
 */
private const val RELATIVE_NOW = "now"

/**
 * Standalone elapsed-time label: "3h ago", "2d ago" — and "Just now"
 * under a minute, because appending the suffix to the sub-minute label
 * by hand produces "now ago".
 */
fun relativeAgoLabel(instant: Instant, now: Instant = Instant.now()): String =
    when (val relative = relativeLabel(instant, now)) {
        RELATIVE_NOW -> "Just now"
        else -> "$relative ago"
    }

/**
 * Same rule for a label already embedded in a sentence ("Posted just
 * now" / "Posted 3h ago"), so the sub-minute case stays lower-case
 * mid-sentence. Takes the [relativeLabel] output rather than the instant
 * because the callers that need this have already formatted it.
 */
internal fun relativeAgoPhrase(relative: String): String =
    if (relative == RELATIVE_NOW) "just now" else "$relative ago"

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
