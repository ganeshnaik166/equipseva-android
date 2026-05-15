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
