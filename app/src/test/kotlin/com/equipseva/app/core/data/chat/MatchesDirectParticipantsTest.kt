package com.equipseva.app.core.data.chat

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the direct-conversation de-dupe predicate. The critical
 * property is order-independence — set equality, not list equality.
 * A regression to list-based comparison would let user A→B and B→A
 * create two distinct "direct" conversation rows.
 */
class MatchesDirectParticipantsTest {

    @Test fun `exact pair matches in either order`() {
        assertTrue(matchesDirectParticipants(listOf("u-1", "u-2"), "u-1", "u-2"))
        assertTrue(matchesDirectParticipants(listOf("u-2", "u-1"), "u-1", "u-2"))
    }

    @Test fun `different pair does not match`() {
        assertFalse(matchesDirectParticipants(listOf("u-1", "u-3"), "u-1", "u-2"))
        assertFalse(matchesDirectParticipants(listOf("u-3", "u-4"), "u-1", "u-2"))
    }

    @Test fun `triple-participant row does not match a direct pair`() {
        // A group-chat conversation (3+ participants) should never
        // match the direct-pair predicate — pin so a future
        // tolerant matcher doesn't accidentally fold groups into
        // direct chats.
        assertFalse(
            matchesDirectParticipants(listOf("u-1", "u-2", "u-3"), "u-1", "u-2"),
        )
    }

    @Test fun `single-participant row does not match`() {
        assertFalse(matchesDirectParticipants(listOf("u-1"), "u-1", "u-2"))
    }

    @Test fun `null participant list returns false (legacy row)`() {
        // Defensive — legacy conversation rows that pre-date the
        // non-null column constraint must not crash the de-dupe.
        assertFalse(matchesDirectParticipants(null, "u-1", "u-2"))
    }

    @Test fun `empty participant list returns false`() {
        assertFalse(matchesDirectParticipants(emptyList(), "u-1", "u-2"))
    }

    @Test fun `duplicate participant id in list does not match (set folds it)`() {
        // ["u-1", "u-1"].toSet() == {"u-1"} — must NOT match the pair
        // {"u-1", "u-2"}. Pin so the self-chat smuggling case fails
        // the de-dupe (a self-paired row shouldn't fold to a direct
        // chat with a different peer).
        assertFalse(matchesDirectParticipants(listOf("u-1", "u-1"), "u-1", "u-2"))
    }

    @Test fun `self == peer is rejected upstream — predicate is set-equal so degenerate input matches`() {
        // The repo's `require(selfUserId != peerUserId)` rejects
        // self-as-peer before this predicate ever runs; pin the set-
        // equality semantics so a future caller that bypasses the
        // require gets a deterministic answer (set equality folds
        // duplicates: {"u-1"} == {"u-1", "u-1"}).
        assertTrue(matchesDirectParticipants(listOf("u-1"), "u-1", "u-1"))
    }
}
