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
    // supabase-kt v3 puts the PostgREST response body in `ex.description`
    // and the status text in `ex.error`. The Throwable `message` is
    // usually the description, but can be a different formatted string
    // depending on which exception subclass is thrown. Concatenate all
    // three so RAISE EXCEPTION literals (e.g. 'kyc_incomplete') match
    // regardless of which field the SDK populated this time.
    val raw = listOfNotNull(ex.message, ex.description, ex.error)
        .joinToString(separator = " | ")
    return when {
        // PostgREST stamps PGRST301 on expired JWTs and PGRST302 on missing /
        // malformed ones. The Supabase SDK auto-refreshes on the next request,
        // so the user usually doesn't need to do anything — but the screen
        // they triggered needs a friendly nudge instead of "JWT expired".
        raw.contains("PGRST301", ignoreCase = true) ||
            raw.contains("PGRST302", ignoreCase = true) ||
            raw.contains("jwt expired", ignoreCase = true) ||
            raw.contains("jwt is invalid", ignoreCase = true) ||
            raw.contains("invalid_jwt", ignoreCase = true) ->
            "Your session expired. Tap retry — if this keeps happening, sign in again."
        // 42501 = insufficient_privilege; also matches the literal phrase
        // Postgres returns when column-level grants block a SELECT.
        raw.contains("42501") || raw.contains("permission denied", ignoreCase = true) ->
            "You don't have access to this yet. Try again after KYC is verified."
        raw.contains("PGRST116", ignoreCase = true) || raw.contains("not found", ignoreCase = true) ->
            "We couldn't find that record."
        raw.contains("23505") -> "That looks like a duplicate. Please try a different value."
        raw.contains("23503") -> "Linked record is missing — refresh and try again."
        // admin_set_engineer_verification raises 'kyc_incomplete' (22023)
        // when an engineer is missing Aadhaar or has no certificates. The
        // raw exception text otherwise falls through to the generic
        // fallback and the admin sees "Something went wrong" instead of
        // an actionable hint.
        raw.contains("kyc_incomplete", ignoreCase = true) ->
            "This engineer is missing Aadhaar verification or has no certificates uploaded. Reject with notes instead, or wait for the engineer to complete KYC."
        // engineer_verify_idempotent_restamp + a few other RPCs return
        // engineer_not_found (02000) when the row was deleted between
        // queue load and resolve action.
        raw.contains("engineer_not_found", ignoreCase = true) ->
            "This engineer's row is no longer in the queue — pull to refresh."
        raw.isNotBlank() && !looksLikeRawDbError(raw) -> raw
        else -> null
    }
}

private fun looksLikeRawDbError(text: String): Boolean =
    text.contains("URL:", ignoreCase = false) ||
        text.contains("permission denied", ignoreCase = true) ||
        text.contains("SQLSTATE", ignoreCase = true) ||
        Regex("\\b\\d{5}\\b").containsMatchIn(text) && text.contains("relation", ignoreCase = true)
