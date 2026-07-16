package com.equipseva.app.core.util

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

// EquipSeva is India-only at v1. Server timestamps land in UTC; users
// expect IST display ("11 May, 11:30 AM") regardless of the device's
// configured time zone. Pinning to Asia/Kolkata keeps display stable
// for travelling users + UTC-default emulators / lab devices (round
// 230 had a Realme on UTC showing dates 5.5 hours behind).
private val IST_ZONE: ZoneId = ZoneId.of("Asia/Kolkata")

/**
 * Render an ISO timestamp (e.g. `2026-05-11T07:42:00Z`) or bare date
 * (`2026-05-11`) as `dd MMM yyyy` in Asia/Kolkata. Falls back to the
 * first 10 chars of the input on parse failure so we never crash on a
 * malformed payload.
 */
fun prettyDate(iso: String): String =
    runCatching {
        // Instant.parse handles full ISO datetimes; LocalDate.parse covers
        // bare-date payloads (the founder KYC RPCs emit "yyyy-MM-dd").
        val instant = runCatching { Instant.parse(iso) }.getOrNull()
            ?: LocalDate.parse(iso).atStartOfDay(IST_ZONE).toInstant()
        // Pin Locale.ENGLISH so month abbreviations stay "May / Jun"
        // regardless of the device locale. Without it, a Hindi-default
        // device renders "11 मई 2026" which clashes with the rest of
        // the English UI strings and breaks copy-paste of dates into
        // support tickets.
        DateTimeFormatter.ofPattern("dd MMM yyyy", Locale.ENGLISH)
            .withZone(IST_ZONE)
            .format(instant)
    }.getOrElse { iso.take(10) }

/**
 * Render an ISO timestamp as `dd MMM yyyy, HH:mm` in Asia/Kolkata
 * (e.g. "11 May 2026, 14:30"). Use when the time portion matters —
 * escrow release schedules, dispute opened-at, founder ops queue
 * audit trails. Falls back to a `yyyy-MM-dd HH:MM` slice on parse
 * failure so we never crash on a malformed payload.
 */
fun prettyDateTime(iso: String): String =
    runCatching {
        val instant = Instant.parse(iso)
        DateTimeFormatter.ofPattern("dd MMM yyyy, HH:mm", Locale.ENGLISH)
            .withZone(IST_ZONE)
            .format(instant)
    }.getOrElse { iso.take(16).replace('T', ' ') }

/**
 * Parse an ISO-8601 instant string into `Instant`, returning null on any
 * failure (null input, malformed payload, missing time-zone designator).
 * Use at DTO -> domain mapping boundaries where a missing/bad timestamp
 * should degrade gracefully rather than crash decoding.
 */
fun String?.parseInstantOrNull(): Instant? =
    this?.let { runCatching { Instant.parse(it) }.getOrNull() }

/**
 * True when [iso] (`yyyy-MM-dd` or full ISO instant) falls within
 * the next [days] calendar days in Asia/Kolkata. Used by Renew-CTA
 * gating (round 314) and any "expires soon" countdown.
 *
 * Returns false on parse failure rather than throwing — bad payload
 * shouldn't render an alarming "expires today" banner.
 */
fun isWithinDays(iso: String, days: Long): Boolean =
    runCatching {
        val target = runCatching { Instant.parse(iso).atZone(IST_ZONE).toLocalDate() }
            .getOrNull()
            ?: LocalDate.parse(iso)
        val today = LocalDate.now(IST_ZONE)
        !target.isBefore(today) && !target.isAfter(today.plusDays(days))
    }.getOrDefault(false)

/**
 * Days remaining until [iso] (`yyyy-MM-dd` or full ISO instant) in
 * Asia/Kolkata. Negative if already past. Null on parse failure.
 * Pairs with [isWithinDays] for surfaces that want to render the
 * exact countdown alongside the gate.
 */
fun daysUntil(iso: String): Long? =
    runCatching {
        val target = runCatching { Instant.parse(iso).atZone(IST_ZONE).toLocalDate() }
            .getOrNull()
            ?: LocalDate.parse(iso)
        java.time.temporal.ChronoUnit.DAYS.between(LocalDate.now(IST_ZONE), target)
    }.getOrNull()

// ---------------------------------------------------------------------
//  Short-horizon SLA countdown (r1429) — used by time-critical surfaces
//  like Code Red where a live "12m left" beats a static timestamp.
//  Pure over epoch millis (now is a parameter) so they unit-test without
//  a clock; the composable passes System.currentTimeMillis() from a ticker.
// ---------------------------------------------------------------------

/** Urgency bucket for an SLA deadline. */
enum class SlaUrgency { Ok, Urgent, Overdue }

/** Minutes-remaining threshold below which an SLA reads [SlaUrgency.Urgent]. */
private const val SLA_URGENT_WINDOW_MS = 15L * 60_000L

/** Countdown to [deadlineEpochMillis] from [nowEpochMillis]:
 *  "Overdue" once passed, "<1m left" under a minute, else "Nm left" /
 *  "Hh left" / "Hh Mm left". */
fun slaCountdownLabel(deadlineEpochMillis: Long, nowEpochMillis: Long): String {
    val remaining = deadlineEpochMillis - nowEpochMillis
    if (remaining <= 0L) return "Overdue"
    val totalMin = remaining / 60_000L
    val h = totalMin / 60L
    val m = totalMin % 60L
    return when {
        totalMin == 0L -> "<1m left"
        h == 0L -> "${m}m left"
        m == 0L -> "${h}h left"
        else -> "${h}h ${m}m left"
    }
}

fun slaUrgency(deadlineEpochMillis: Long, nowEpochMillis: Long): SlaUrgency {
    val remaining = deadlineEpochMillis - nowEpochMillis
    return when {
        remaining <= 0L -> SlaUrgency.Overdue
        remaining <= SLA_URGENT_WINDOW_MS -> SlaUrgency.Urgent
        else -> SlaUrgency.Ok
    }
}

/** Convenience over an ISO deadline string. Null when [iso] can't be parsed
 *  (callers then fall back to a plain date). */
fun slaCountdownLabel(iso: String?, nowEpochMillis: Long): String? =
    iso.parseInstantOrNull()?.let { slaCountdownLabel(it.toEpochMilli(), nowEpochMillis) }

fun slaUrgency(iso: String?, nowEpochMillis: Long): SlaUrgency? =
    iso.parseInstantOrNull()?.let { slaUrgency(it.toEpochMilli(), nowEpochMillis) }
