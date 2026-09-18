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
/**
 * Parse a server timestamp. PostgREST renders `timestamptz` with an explicit
 * numeric offset (`2026-05-11T07:42:00.123456+00:00`), never `Z`. On the
 * OpenJDK 8/11 libcore that Android 8–13 ship, `Instant.parse` accepts ONLY
 * `Z` (JDK-8166138, fixed in JDK 12), so every server instant came back null
 * there — notifications never left the unread state, job/bid/chat times were
 * blank — while JVM tests and API 34+ emulators (JDK 17) never showed it.
 * `OffsetDateTime` parses both forms on every supported API level.
 */
internal fun parseIsoInstant(iso: String): Instant? =
    runCatching { java.time.OffsetDateTime.parse(iso).toInstant() }.getOrNull()
        ?: runCatching { Instant.parse(iso) }.getOrNull()

fun prettyDate(iso: String): String =
    runCatching {
        // Full ISO datetimes first; LocalDate.parse covers bare-date payloads
        // (the founder KYC RPCs emit "yyyy-MM-dd").
        val instant = parseIsoInstant(iso)
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
        val instant = parseIsoInstant(iso) ?: throw IllegalArgumentException("not an ISO instant")
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
    this?.let { parseIsoInstant(it) }

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
        val target = parseIsoInstant(iso)?.atZone(IST_ZONE)?.toLocalDate()
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
        val target = parseIsoInstant(iso)?.atZone(IST_ZONE)?.toLocalDate()
            ?: LocalDate.parse(iso)
        java.time.temporal.ChronoUnit.DAYS.between(LocalDate.now(IST_ZONE), target)
    }.getOrNull()
