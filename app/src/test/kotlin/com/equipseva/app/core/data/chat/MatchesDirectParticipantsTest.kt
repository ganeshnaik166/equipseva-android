package com.equipseva.app.core.data.chat

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Direct-chat dedup runs entirely client-side: we fetch every direct
 * conversation visible to the caller, then match on participant set.
 * If this matcher silently flips back to list equality (order-sensitive),
 * every "open chat with X" tap from a vendor-side entry would create a
 * second direct row, and the conversation list would show duplicates.
 */
class MatchesDirectParticipantsTest {

    @Test fun `matches when stored participants are the same set in the same order`() {
        assertTrue(matchesDirectParticipants(listOf("u1", "u2"), "u1", "u2"))
    }

    @Test fun `matches when stored participants are the same set in reversed order`() {
        // This is the load-bearing case — Postgres returns whatever order the
        // array was inserted with, and the caller pair has no canonical order.
        assertTrue(matchesDirectParticipants(listOf("u2", "u1"), "u1", "u2"))
    }

    @Test fun `rejects when one participant is missing`() {
        assertFalse(matchesDirectParticipants(listOf("u1", "u3"), "u1", "u2"))
    }

    @Test fun `rejects when stored has an extra participant`() {
        // setOf("u1","u2","u3") != setOf("u1","u2") — guards against
        // accidentally matching a 3-way chat once group chats land.
        assertFalse(matchesDirectParticipants(listOf("u1", "u2", "u3"), "u1", "u2"))
    }

    @Test fun `rejects when stored is null`() {
        // A row with a null participant_user_ids column never matches anyone —
        // shouldn't be possible in practice (NOT NULL on the column) but the
        // DTO models it as nullable, so pin the safe behavior.
        assertFalse(matchesDirectParticipants(null, "u1", "u2"))
    }

    @Test fun `rejects when stored is empty`() {
        assertFalse(matchesDirectParticipants(emptyList(), "u1", "u2"))
    }

    @Test fun `dedups duplicate ids in the stored list against the pair set`() {
        // Set semantics: ["u1","u1"] becomes {"u1"} which can't equal {"u1","u2"}.
        // Catches a malformed row from a future bulk-insert that doubled an id.
        assertFalse(matchesDirectParticipants(listOf("u1", "u1"), "u1", "u2"))
    }
}
