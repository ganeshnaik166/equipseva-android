package com.equipseva.app.core.network

import io.github.jan.supabase.exceptions.HttpRequestException
import io.github.jan.supabase.exceptions.RestException
import kotlinx.coroutines.CancellationException
import java.io.IOException

/**
 * Translates anything thrown by Supabase / Ktor / IO into a stable user-facing
 * message. ViewModels that aren't auth-specific should use this rather than
 * `toAuthError()`, which carries auth-flavoured copy.
 */
fun Throwable.toUserMessage(fallback: String = "Something went wrong. Please try again."): String {
    if (this is CancellationException) throw this
    return when (this) {
        is HttpRequestException, is IOException -> "Network problem. Check your connection and retry."
        // Postgrest errors carry raw SQL text + URL in `message` (e.g.
        // "permission denied for table organizations / URL: ..."). Surfacing
        // that to users leaks schema and reads as gibberish, so map known
        // SQLSTATE codes to friendly copy and fall back to a generic line.
        is RestException -> friendlyRestMessage(this) ?: fallback
        else -> message?.takeIf { it.isNotBlank() && !looksLikeRawDbError(it) } ?: fallback
    }
}

private fun friendlyRestMessage(ex: RestException): String? {
    val raw = ex.message.orEmpty()
    return when {
        // 42501 = insufficient_privilege; also matches the literal phrase
        // Postgres returns when column-level grants block a SELECT.
        raw.contains("42501") || raw.contains("permission denied", ignoreCase = true) ->
            "You don't have access to this yet. Try again after KYC is verified."
        raw.contains("PGRST116", ignoreCase = true) || raw.contains("not found", ignoreCase = true) ->
            "We couldn't find that record."
        raw.contains("23505") -> "That looks like a duplicate. Please try a different value."
        raw.contains("23503") -> "Linked record is missing — refresh and try again."
        raw.isNotBlank() && !looksLikeRawDbError(raw) -> raw
        else -> null
    }
}

private fun looksLikeRawDbError(text: String): Boolean =
    text.contains("URL:", ignoreCase = false) ||
        text.contains("permission denied", ignoreCase = true) ||
        text.contains("SQLSTATE", ignoreCase = true) ||
        Regex("\\b\\d{5}\\b").containsMatchIn(text) && text.contains("relation", ignoreCase = true)
