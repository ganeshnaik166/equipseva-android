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
        // r1492 — user-facing server RAISE EXCEPTION codes, traced from
        // supabase/migrations to real hospital/engineer client callers. These
        // sit ABOVE the generic SQLSTATE matchers so a specific code wins —
        // most importantly only_accepted_engineer_can_checkin, which is raised
        // with ERRCODE 42501 and would otherwise get the wrong KYC-flavoured
        // 42501 copy below. Substring-collision rule: longer literal first.
        raw.contains("only_accepted_engineer_can_checkin", ignoreCase = true) ->
            "Only the engineer awarded this job can check in or out on site."
        raw.contains("equipment_type_out_of_scope_for_code_red", ignoreCase = true) ->
            "That equipment type isn't eligible for a Code Red. Pick one of the listed types and try again."
        raw.contains("equipment_type_out_of_scope", ignoreCase = true) ->
            "EquipSeva doesn't service that equipment type yet. Pick a different equipment category, or contact support if you think it should be covered."
        raw.contains("invite_not_found_or_expired", ignoreCase = true) ->
            "That invite code didn't work — it may have expired or already been used. Ask the chain admin to send you a fresh invite."
        raw.contains("invite_not_found", ignoreCase = true) ->
            "That invite is no longer available — refresh and try again."
        raw.contains("chat_conversation_closed", ignoreCase = true) ->
            "This chat is closed because the repair job has ended. Contact support if you still need to reach the other party."
        raw.contains("chat_rate_limited_conversation", ignoreCase = true) ->
            "You're sending messages too quickly. Wait a moment, then try again."
        raw.contains("chat_rate_limited_user", ignoreCase = true) ->
            "You've sent too many messages in a short time. Take a short break and try again later."
        raw.contains("code_red_sla_expired", ignoreCase = true) ->
            "This Code Red's response window has passed, so it can no longer be accepted. It'll clear from your list on the next refresh."
        raw.contains("code_red_not_found", ignoreCase = true) ->
            "This Code Red is no longer available — pull to refresh."
        raw.contains("escrow_not_found", ignoreCase = true) ->
            "We couldn't find that escrow anymore — pull to refresh and try again."
        raw.contains("amc_contract_not_found", ignoreCase = true) ->
            "We couldn't find this AMC contract — it may have been cancelled. Pull to refresh and try again."
        raw.contains("address_not_found", ignoreCase = true) ->
            "That address is no longer saved. Refresh your address list and try again."
        raw.contains("renewal_not_in_progress", ignoreCase = true) ->
            "This KYC renewal has already been closed. Pull to refresh to see its latest status."
        raw.contains("no_accepted_engineer", ignoreCase = true) ->
            "This job doesn't have an assigned engineer yet. Pull to refresh and try again once a bid has been accepted."
        raw.contains("valid_email_required", ignoreCase = true) ->
            "That doesn't look like a valid email address. Check it and try again."
        // r1494 — second batch of user-reachable server codes (traced via the
        // error-copy-mapping-2 sweep). Same rules: specific literals above the
        // generic SQLSTATE matchers; the 42501-raised ones stay above the 42501
        // branch below; repair_job_not_found before job_not_found (substring).
        raw.contains("not_paged_for_this_code_red", ignoreCase = true) ->
            "You're no longer on the responder list for this Code Red, so it can't be accepted. Pull to refresh."
        raw.contains("invite_email_mismatch", ignoreCase = true) ->
            "This invite was sent to a different email address. Sign in with the account it was emailed to, then try again."
        raw.contains("engineer_only_can_submit_dsr", ignoreCase = true) ->
            "Only the engineer awarded this job can file its service report."
        raw.contains("code_red_not_open", ignoreCase = true) ->
            "This Code Red is no longer open — another engineer may have accepted it first. It'll clear from your list on the next refresh."
        raw.contains("no_paged_event_for_caller", ignoreCase = true) ->
            "You've already responded to this Code Red, or another engineer took it first — pull to refresh."
        raw.contains("equipment_category_out_of_scope", ignoreCase = true) ->
            "EquipSeva doesn't cover one of those equipment categories yet. Remove it from the contract, or contact support if you think it should be covered."
        raw.contains("equipment_type_unknown", ignoreCase = true) ->
            "EquipSeva doesn't service that equipment type yet. Pick a different equipment category, or contact support if you think it should be covered."
        raw.contains("renewal_not_pending", ignoreCase = true) ->
            "This KYC renewal has already been started or closed. Pull to refresh to see its latest status."
        raw.contains("pack_must_have_evidence_or_dsr_before_submit", ignoreCase = true) ->
            "Add at least one piece of evidence before filing this dispute for mediation."
        raw.contains("dsr_not_found", ignoreCase = true) ->
            "We couldn't find this service report anymore — pull to refresh and try again."
        raw.contains("bid_not_found", ignoreCase = true) ->
            "That bid is no longer available — pull to refresh your bids and try again."
        raw.contains("repair_job_not_found", ignoreCase = true) ->
            "We couldn't find this repair job anymore — pull to refresh and try again."
        raw.contains("job_not_found", ignoreCase = true) ->
            "We couldn't find that repair job anymore — pull to refresh and try again."
        // r1506 — final census batch: an engineer confirming a pending
        // referral whose bounty was revoked (round568 guard, ERRCODE 22023).
        raw.contains("referral_revoked", ignoreCase = true) ->
            "This referral's bounty was revoked, so it can no longer be confirmed. It'll clear from your list on the next refresh — contact support if you think this is a mistake."
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
        // r1387 engineer referral bounty (round564) RAISE EXCEPTION literals.
        raw.contains("cannot_refer_self", ignoreCase = true) ->
            "You can't refer yourself."
        raw.contains("referral_already_registered", ignoreCase = true) ->
            "You've already recorded a referral — each engineer can only be referred once."
        raw.contains("referrer_not_an_engineer", ignoreCase = true) ->
            "That code doesn't match an EquipSeva engineer. Double-check it with whoever referred you."
        raw.contains("referrer_required", ignoreCase = true) ->
            "Enter a referral code first."
        raw.isNotBlank() && !looksLikeRawDbError(raw) -> raw
        else -> null
    }
}

private fun looksLikeRawDbError(text: String): Boolean =
    text.contains("URL:", ignoreCase = false) ||
        text.contains("permission denied", ignoreCase = true) ||
        text.contains("SQLSTATE", ignoreCase = true) ||
        Regex("\\b\\d{5}\\b").containsMatchIn(text) && text.contains("relation", ignoreCase = true)
