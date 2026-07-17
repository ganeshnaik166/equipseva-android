package com.equipseva.app.core.util

/**
 * Server RPCs frequently `coalesce(p.full_name, '(unnamed)')` (or `'(unknown)'`,
 * or `coalesce(full_name, email, '(unnamed)')`) so the wire value is never
 * null/blank — it's a literal placeholder. Client guards that only check
 * `isNotBlank()` therefore leak that DB sentinel straight into the UI (a
 * founder sees "(unnamed) → (unnamed)", an avatar initial of "(", etc.).
 *
 * [sanitizeServerName] treats those sentinels (and blank) as ABSENT, returning
 * null so the caller can apply its own human fallback ("Hospital", "Engineer",
 * an email/phone chain, …). Case-insensitive + trimmed.
 *
 * Pinned in DisplayNamesTest. If a new server placeholder token appears, add it
 * here rather than guarding it at each call site.
 */
private val SERVER_NAME_SENTINELS = setOf("(unnamed)", "(unknown)", "(no name)")

fun sanitizeServerName(raw: String?): String? =
    raw?.trim()?.takeIf { it.isNotEmpty() && it.lowercase() !in SERVER_NAME_SENTINELS }
