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
        // Error-copy census (ported from a historical fix batch, but
        // RE-VERIFIED against THIS branch's own supabase/migrations + actual
        // Android RPC/table callers rather than trusted as-is — see the
        // "Windows handoff" memory note on why that distinction matters
        // here). The historical batch mapped 30 server RAISE EXCEPTION
        // codes; only 7 have a live client-reachable path on this branch —
        // the taxonomy-gate + chat triggers (both fire on this app's actual
        // direct .insert() calls) and address_set_default. The other 23
        // (Code Red, hospital-chain invites, DSR/evidence-pack/mediation,
        // referral bounty, periodic re-KYC, AMC affidavit signing, escrow
        // force-release, first-job-free, job-profitability) are raised only
        // by RPCs/screens that don't exist on this branch — including them
        // would be dead code asserting a false "user-reachable" claim.
        // Flagship example of why this needed re-verification, not a blind
        // port: the historical fix's headline case
        // (only_accepted_engineer_can_checkin, ERRCODE 42501, allegedly
        // mis-mapped to the KYC-flavoured 42501 copy below) turned out to be
        // raised by record_engineer_attendance, a function this app's actual
        // check-in path (engineer_check_in_with_geo) never calls — so it was
        // excluded here too.
        raw.contains("equipment_type_out_of_scope", ignoreCase = true) ->
            "EquipSeva doesn't service that equipment type yet. Pick a different equipment category, or contact support if you think it should be covered."
        raw.contains("equipment_type_unknown", ignoreCase = true) ->
            "EquipSeva doesn't service that equipment type yet. Pick a different equipment category, or contact support if you think it should be covered."
        raw.contains("equipment_category_out_of_scope", ignoreCase = true) ->
            "EquipSeva doesn't cover one of those equipment categories yet. Remove it from the contract, or contact support if you think it should be covered."
        raw.contains("chat_conversation_closed", ignoreCase = true) ->
            "This chat is closed because the repair job has ended. Contact support if you still need to reach the other party."
        raw.contains("chat_rate_limited_conversation", ignoreCase = true) ->
            "You're sending messages too quickly. Wait a moment, then try again."
        raw.contains("chat_rate_limited_user", ignoreCase = true) ->
            "You've sent too many messages in a short time. Take a short break and try again later."
        raw.contains("address_not_found", ignoreCase = true) ->
            "That address is no longer saved. Refresh your address list and try again."
        // 42501 = insufficient_privilege; also matches the literal phrase
        // Postgres returns when column-level grants block a SELECT.
        raw.contains("42501") || raw.contains("permission denied", ignoreCase = true) ->
            "You don't have access to this yet. Try again after KYC is verified."
        raw.contains("PGRST116", ignoreCase = true) || raw.contains("not found", ignoreCase = true) ->
            "We couldn't find that record."
        // Phone-uniqueness has its own constraint name; surface specific
        // copy so users know to enter a different number rather than
        // reading "duplicate value" cold. supabase-kt's RestException.message
        // wraps the Postgrest JSON body — the 23505 SQLSTATE is rarely
        // included verbatim, so match the human-readable phrases too.
        raw.contains("profiles_phone_unique", ignoreCase = true) ->
            "That phone number is already on another EquipSeva account."
        raw.contains("23505") ||
            raw.contains("duplicate key", ignoreCase = true) ||
            raw.contains("already exists", ignoreCase = true) ||
            raw.contains("unique constraint", ignoreCase = true) ->
            "That looks like a duplicate. Please try a different value."
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
        // r576 + r585 supervised training error mappings. ERRCODE 0L000
        // covers all illegal-state transitions; match on the literal
        // RAISE EXCEPTION text since each one needs a distinct hint.
        raw.contains("no signed DSR", ignoreCase = true) ->
            "Hospital hasn't signed the DSR yet. Ask the hospital to accept the repair, then sign off."
        raw.contains("only the named supervisor", ignoreCase = true) ->
            "Only the assigned supervisor can take this action."
        raw.contains("only the accepted-bid engineer", ignoreCase = true) ->
            "Only the engineer who was awarded this job can request supervision."
        raw.contains("supervisor tier", ignoreCase = true) &&
            raw.contains("strictly higher", ignoreCase = true) ->
            "Supervisor must be a strictly higher tier than you."
        raw.contains("supervisor is not an active verified engineer", ignoreCase = true) ->
            "That supervisor is no longer an active verified engineer."
        raw.contains("cannot supervise self", ignoreCase = true) ->
            "You can't supervise yourself."
        raw.contains("cannot accept from state", ignoreCase = true) ||
            raw.contains("cannot decline from state", ignoreCase = true) ||
            raw.contains("cannot signoff from state", ignoreCase = true) ->
            "This request has moved past that step — pull to refresh."
        raw.isNotBlank() && !looksLikeRawDbError(raw) -> raw
        else -> null
    }
}

private fun looksLikeRawDbError(text: String): Boolean =
    text.contains("URL:", ignoreCase = false) ||
        text.contains("permission denied", ignoreCase = true) ||
        text.contains("SQLSTATE", ignoreCase = true) ||
        Regex("\\b\\d{5}\\b").containsMatchIn(text) && text.contains("relation", ignoreCase = true)
