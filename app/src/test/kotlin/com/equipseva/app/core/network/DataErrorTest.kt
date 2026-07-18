package com.equipseva.app.core.network

import io.github.jan.supabase.exceptions.RestException
import kotlinx.coroutines.CancellationException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.IOException

// Round 423 — Throwable.toUserMessage is the funnel between Supabase /
// Ktor errors and user-visible toasts. A regression here either leaks
// raw SQL / URL strings to users or swallows actionable failures behind
// a generic fallback. The branch matrix is wide (10+ phrase / SQLSTATE
// matchers); pin each on a representative input.
class DataErrorTest {

    private val fallback = "Something went wrong. Please try again."

    // ---------------------------------------------------------------------
    //  CancellationException — must re-throw, never swallow
    // ---------------------------------------------------------------------

    @Test fun `CancellationException is rethrown, not converted`() {
        val ex = CancellationException("scope cancelled")
        assertThrows(CancellationException::class.java) { ex.toUserMessage() }
    }

    // ---------------------------------------------------------------------
    //  Network errors — Ktor / IOException → generic offline copy
    // ---------------------------------------------------------------------

    @Test fun `IOException maps to network problem`() {
        val msg = IOException("connection refused").toUserMessage()
        assertEquals("Network problem. Check your connection and retry.", msg)
    }

    // HttpRequestException's constructor requires an HttpRequestBuilder
    // which we'd have to import + stub; the IOException branch above
    // covers the same when{} arm of toUserMessage, so the network-error
    // class is sufficiently exercised.

    // ---------------------------------------------------------------------
    //  Generic Throwables — clean .message survives if it isn't a raw DB error
    // ---------------------------------------------------------------------

    @Test fun `generic exception with safe message returns the message`() {
        val msg = RuntimeException("Add a valid email first.").toUserMessage()
        assertEquals("Add a valid email first.", msg)
    }

    @Test fun `generic exception with blank message returns fallback`() {
        val msg = RuntimeException("   ").toUserMessage()
        assertEquals(fallback, msg)
    }

    @Test fun `generic exception with null message returns fallback`() {
        val msg = RuntimeException(null as String?).toUserMessage()
        assertEquals(fallback, msg)
    }

    @Test fun `generic exception with raw URL-tagged message returns fallback`() {
        // looksLikeRawDbError trips on "URL:" — supabase-kt v3 stamps these
        // into RestException.message for PostgREST 4xx/5xx. Even if the
        // exception type is plain RuntimeException, the heuristic should
        // still reject the message.
        val msg = RuntimeException(
            "permission denied for table organizations / URL: https://x.supabase.co/rest/v1/orgs"
        ).toUserMessage()
        assertEquals(fallback, msg)
    }

    @Test fun `generic exception mentioning SQLSTATE returns fallback`() {
        val msg = RuntimeException(
            "ERROR: duplicate key value violates SQLSTATE 23505 on relation chats"
        ).toUserMessage()
        assertEquals(fallback, msg)
    }

    // ---------------------------------------------------------------------
    //  RestException — friendly mapping for SQLSTATE / PostgREST codes
    // ---------------------------------------------------------------------
    //
    // RestException's primary constructor needs a status + description; the
    // sealed/abstract status varies across supabase-kt versions. Use the
    // concrete UnknownRestException subtype which the SDK ships for "any
    // other postgrest error" — its constructor takes (errorCode, message,
    // statusCode).

    // 4-arg ctor on the public class: (error, description, statusCode, message).
    // toUserMessage's friendlyRestMessage joins all three string fields with
    // " | ", so any of them carries the matcher text.
    private fun rest(description: String): RestException =
        RestException(
            error = "PostgrestError",
            description = description,
            statusCode = 400,
            message = description,
        )

    @Test fun `expired JWT maps to session-expired copy`() {
        val msg = rest("JWT expired").toUserMessage()
        assertTrue("got: $msg", msg.contains("session expired", ignoreCase = true))
    }

    @Test fun `PGRST301 maps to session-expired copy`() {
        val msg = rest("PGRST301 token expired").toUserMessage()
        assertTrue("got: $msg", msg.contains("session expired", ignoreCase = true))
    }

    @Test fun `SQLSTATE 42501 permission denied maps to kyc gate copy`() {
        val msg = rest("permission denied for table profiles, code 42501").toUserMessage()
        assertTrue("got: $msg", msg.contains("don't have access", ignoreCase = true))
        assertTrue("got: $msg", msg.contains("KYC", ignoreCase = true))
    }

    @Test fun `PGRST116 not found maps to record-missing copy`() {
        val msg = rest("PGRST116 The result contains 0 rows").toUserMessage()
        assertTrue("got: $msg", msg.contains("couldn't find", ignoreCase = true))
    }

    @Test fun `profiles_phone_unique constraint maps to specific copy`() {
        val msg = rest("duplicate key value violates unique constraint profiles_phone_unique").toUserMessage()
        assertTrue("got: $msg", msg.contains("phone number is already", ignoreCase = true))
        // The generic duplicate copy must NOT fire — phone-specific takes
        // precedence so the user knows to swap the phone, not the value.
    }

    @Test fun `generic 23505 duplicate maps to duplicate copy`() {
        val msg = rest("duplicate key value, code 23505").toUserMessage()
        assertTrue("got: $msg", msg.contains("duplicate", ignoreCase = true))
    }

    @Test fun `23503 foreign-key maps to linked-record copy`() {
        val msg = rest("violates foreign key constraint, code 23503").toUserMessage()
        assertTrue("got: $msg", msg.contains("linked record", ignoreCase = true))
    }

    @Test fun `kyc_incomplete custom raise maps to actionable copy`() {
        // admin_set_engineer_verification raises 'kyc_incomplete' (22023)
        // when the engineer is missing Aadhaar or certificates. The custom
        // mapping turns this from generic toast into actionable guidance.
        val msg = rest("kyc_incomplete").toUserMessage()
        assertTrue("got: $msg", msg.contains("Aadhaar", ignoreCase = true))
        assertTrue("got: $msg", msg.contains("certificate", ignoreCase = true))
    }

    @Test fun `engineer_not_found maps to pull-to-refresh hint`() {
        val msg = rest("engineer_not_found").toUserMessage()
        assertTrue("got: $msg", msg.contains("pull to refresh", ignoreCase = true))
    }

    @Test fun `unknown RestException with safe text passes through`() {
        // If nothing matches and the text doesn't look like a raw DB error,
        // surface it. friendlyRestMessage concatenates message | description
        // | error with " | " before falling through, so assert contains()
        // not equals() — the user sees the meaningful text inside the join.
        val msg = rest("Phone number required to accept jobs.").toUserMessage()
        assertTrue("got: $msg", msg.contains("Phone number required to accept jobs."))
    }

    @Test fun `unknown RestException with URL-tagged raw text falls back`() {
        // Use "URL:" alone — looksLikeRawDbError trips on that token. Avoid
        // every matcher phrase ("permission denied" → 42501, "not found" →
        // PGRST116, "duplicate" → 23505, etc.) so this only exercises the
        // looksLikeRawDbError fallback.
        val msg = rest("schema column issue / URL: https://x.supabase.co/rest").toUserMessage()
        assertEquals(fallback, msg)
    }

    // ---------------------------------------------------------------------
    //  r1492 — user-facing server RAISE EXCEPTION codes
    // ---------------------------------------------------------------------

    @Test fun `only_accepted_engineer_can_checkin beats the generic 42501 copy`() {
        // Raised server-side with ERRCODE 42501, so the raw text carries both
        // the literal AND "42501". The dedicated branch must win over the
        // generic 42501 "KYC verified" copy (the mis-mapping this fixes).
        val msg = rest("only_accepted_engineer_can_checkin (SQLSTATE 42501)").toUserMessage()
        assertTrue("got: $msg", msg.contains("awarded this job", ignoreCase = true))
        assertTrue("must not show KYC copy, got: $msg", !msg.contains("KYC", ignoreCase = true))
    }

    @Test fun `equipment_type_out_of_scope_for_code_red maps to the code-red copy, not the general one`() {
        val msg = rest("equipment_type_out_of_scope_for_code_red").toUserMessage()
        assertTrue("got: $msg", msg.contains("Code Red", ignoreCase = true))
    }

    @Test fun `equipment_type_out_of_scope maps to the general scope copy`() {
        val msg = rest("equipment_type_out_of_scope").toUserMessage()
        assertTrue("got: $msg", msg.contains("doesn't service", ignoreCase = true))
        assertTrue("general copy must not mention Code Red, got: $msg", !msg.contains("Code Red", ignoreCase = true))
    }

    @Test fun `invite_not_found_or_expired maps to the expired-invite copy, not the shorter one`() {
        val msg = rest("invite_not_found_or_expired").toUserMessage()
        assertTrue("got: $msg", msg.contains("expired", ignoreCase = true))
    }

    @Test fun `invite_not_found maps to the refresh copy`() {
        val msg = rest("invite_not_found").toUserMessage()
        assertTrue("got: $msg", msg.contains("no longer available", ignoreCase = true))
    }

    @Test fun `chat_conversation_closed maps to job-ended copy`() {
        val msg = rest("chat_conversation_closed").toUserMessage()
        assertTrue("got: $msg", msg.contains("closed", ignoreCase = true))
    }

    @Test fun `chat_rate_limited_user maps to slow-down copy`() {
        val msg = rest("chat_rate_limited_user").toUserMessage()
        assertTrue("got: $msg", msg.contains("too many messages", ignoreCase = true))
    }

    @Test fun `code_red_sla_expired maps to window-passed copy`() {
        val msg = rest("code_red_sla_expired").toUserMessage()
        assertTrue("got: $msg", msg.contains("response window", ignoreCase = true))
    }

    @Test fun `amc_contract_not_found maps to friendly copy, not raw code`() {
        val msg = rest("amc_contract_not_found").toUserMessage()
        assertTrue("got: $msg", msg.contains("AMC contract", ignoreCase = true))
        assertTrue("raw code must not leak, got: $msg", !msg.contains("amc_contract_not_found"))
    }

    @Test fun `no_accepted_engineer maps to friendly copy`() {
        val msg = rest("no_accepted_engineer").toUserMessage()
        assertTrue("got: $msg", msg.contains("assigned engineer", ignoreCase = true))
    }

    // ---------------------------------------------------------------------
    //  r1494 — second batch of user-reachable server codes
    // ---------------------------------------------------------------------

    @Test fun `not_paged_for_this_code_red beats the generic 42501 copy`() {
        val msg = rest("not_paged_for_this_code_red (SQLSTATE 42501)").toUserMessage()
        assertTrue("got: $msg", msg.contains("responder list", ignoreCase = true))
        assertTrue("must not show KYC copy, got: $msg", !msg.contains("KYC", ignoreCase = true))
    }

    @Test fun `invite_email_mismatch beats the generic 42501 copy`() {
        val msg = rest("invite_email_mismatch (SQLSTATE 42501)").toUserMessage()
        assertTrue("got: $msg", msg.contains("different email", ignoreCase = true))
        assertTrue("must not show KYC copy, got: $msg", !msg.contains("KYC", ignoreCase = true))
    }

    @Test fun `engineer_only_can_submit_dsr beats the generic 42501 copy`() {
        val msg = rest("engineer_only_can_submit_dsr (SQLSTATE 42501)").toUserMessage()
        assertTrue("got: $msg", msg.contains("file its service report", ignoreCase = true))
        assertTrue("must not show KYC copy, got: $msg", !msg.contains("KYC", ignoreCase = true))
    }

    @Test fun `repair_job_not_found maps to friendly copy, not raw code`() {
        val msg = rest("repair_job_not_found").toUserMessage()
        assertTrue("got: $msg", msg.contains("repair job", ignoreCase = true))
        assertTrue("raw code must not leak, got: $msg", !msg.contains("repair_job_not_found"))
    }

    @Test fun `code_red_not_open maps to already-accepted copy`() {
        val msg = rest("code_red_not_open").toUserMessage()
        assertTrue("got: $msg", msg.contains("no longer open", ignoreCase = true))
    }

    @Test fun `renewal_not_pending maps to friendly copy, not raw code`() {
        val msg = rest("renewal_not_pending (status=in_progress)").toUserMessage()
        assertTrue("got: $msg", msg.contains("KYC renewal", ignoreCase = true))
        assertTrue("raw code must not leak, got: $msg", !msg.contains("renewal_not_pending"))
    }

    @Test fun `equipment_type_unknown maps to friendly copy, not raw schema hint`() {
        val msg = rest("equipment_type_unknown").toUserMessage()
        assertTrue("got: $msg", msg.contains("doesn't service", ignoreCase = true))
        assertTrue("raw code must not leak, got: $msg", !msg.contains("equipment_type_unknown"))
    }

    @Test fun `bid_not_found maps to friendly copy`() {
        val msg = rest("bid_not_found").toUserMessage()
        assertTrue("got: $msg", msg.contains("bid is no longer", ignoreCase = true))
    }

    @Test fun `referral_revoked maps to friendly copy, not raw code`() {
        // r1506 — the last user-reachable code from the full 107-code census.
        val msg = rest("referral_revoked").toUserMessage()
        assertTrue("got: $msg", msg.contains("bounty was revoked", ignoreCase = true))
        assertTrue("raw code must not leak, got: $msg", !msg.contains("referral_revoked"))
    }
}
