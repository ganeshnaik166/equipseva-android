package com.equipseva.app.core.util

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/**
 * Render an ISO timestamp (e.g. `2026-05-11T07:42:00Z`) or bare date
 * (`2026-05-11`) as `dd MMM yyyy` in the device's default zone. Falls
 * back to the first 10 chars of the input on parse failure so we never
 * crash on a malformed payload.
 */
fun prettyDate(iso: String): String =
    runCatching {
        // Instant.parse handles full ISO datetimes; LocalDate.parse covers
        // bare-date payloads (the founder KYC RPCs emit "yyyy-MM-dd").
        val instant = runCatching { Instant.parse(iso) }.getOrNull()
            ?: LocalDate.parse(iso).atStartOfDay(ZoneId.systemDefault()).toInstant()
        DateTimeFormatter.ofPattern("dd MMM yyyy")
            .withZone(ZoneId.systemDefault())
            .format(instant)
    }.getOrElse { iso.take(10) }

/**
 * Render an ISO timestamp as `dd MMM yyyy, HH:mm` in the device's
 * default zone (e.g. "11 May 2026, 14:30"). Use when the time portion
 * matters — escrow release schedules, dispute opened-at, founder ops
 * queue audit trails. Falls back to a `yyyy-MM-dd HH:MM` slice on
 * parse failure so we never crash on a malformed payload.
 */
fun prettyDateTime(iso: String): String =
    runCatching {
        val instant = Instant.parse(iso)
        DateTimeFormatter.ofPattern("dd MMM yyyy, HH:mm")
            .withZone(ZoneId.systemDefault())
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
