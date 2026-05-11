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
