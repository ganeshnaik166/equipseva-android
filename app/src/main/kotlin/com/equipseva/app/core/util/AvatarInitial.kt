package com.equipseva.app.core.util

/**
 * Single-letter avatar initial. Reads from [primary] first (typically a
 * fullName), falls back to [secondary] (typically an email's local-part)
 * when primary is null/blank, and finally to [blankFallback] when both
 * are missing — used by the avatar circles on the founder dashboard
 * surfaces so the chip is never empty.
 *
 * Lowercase letters are upper-cased so a "ravi" fullName still renders
 * as `R`, matching the rest of the design-system avatar styling.
 *
 * The two-letter `chatInitialsOf` (e.g. `Ganesh Dhanavath` → `GD`)
 * lives separately in features/chat because it splits on whitespace
 * and the policy differs — keep them distinct.
 */
internal fun avatarInitial(
    primary: String?,
    secondary: String? = null,
    blankFallback: String = "?",
): String =
    primary?.firstOrNull()?.uppercaseChar()?.toString()
        ?: secondary?.firstOrNull()?.uppercaseChar()?.toString()
        ?: blankFallback
