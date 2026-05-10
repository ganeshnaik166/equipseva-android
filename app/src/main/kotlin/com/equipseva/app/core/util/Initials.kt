package com.equipseva.app.core.util

/**
 * Two-character initials derived from the first letter of the first
 * two whitespace-separated tokens in [name]. "Ramesh Kumar" → "RK",
 * "Priyanka" → "P", "" → "?".
 *
 * Avatar previously rendered `name.take(2).uppercase()` at three
 * call-sites (HomeHub recommended carousel, engineer public profile
 * fallback, repeat-booking nudge), which produced "RA" instead of
 * "RK" for "Ramesh Kumar" — visually noisy and inconsistent with
 * Chat/Conversations/RepairJobDetail, which already used the proper
 * initials helper. Centralising here so every avatar agrees.
 */
fun initialsOf(name: String): String =
    name.split(" ", limit = 2)
        .mapNotNull { it.firstOrNull()?.uppercaseChar()?.toString() }
        .joinToString("")
        .take(2)
        .ifBlank { "?" }
