package com.equipseva.app.core.data.chat

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ChatMessageSenderMismatchReasonTest {

    @Test fun `matching ids allow drain (returns null)`() {
        assertNull(chatMessageSenderMismatchReason("u-1", "u-1"))
    }

    @Test fun `mismatched ids drop with both ids in the reason`() {
        // Critical pin — shared-device case. User B is signed in but
        // user A's chat message is queued. The handler must drop the
        // row so the worker doesn't burn the 5-attempt retry budget
        // round-tripping a row chat_messages RLS will silently reject.
        val reason = chatMessageSenderMismatchReason("u-1", "u-2")
        assertEquals("Sender mismatch: queued as u-1, current auth is u-2", reason)
    }

    @Test fun `case difference counts as mismatch`() {
        // UUIDs are lowercase on the wire — pin case-sensitivity so a
        // future refactor that uppercases either side doesn't silently
        // start dropping its own queued messages.
        val reason = chatMessageSenderMismatchReason(
            "ABCDEF00-0000-0000-0000-000000000001",
            "abcdef00-0000-0000-0000-000000000001",
        )
        assertEquals(
            "Sender mismatch: queued as ABCDEF00-0000-0000-0000-000000000001, " +
                "current auth is abcdef00-0000-0000-0000-000000000001",
            reason,
        )
    }

    @Test fun `whitespace difference counts as mismatch (no trimming)`() {
        // Pin — caller is responsible for normalising ids. The gate is
        // a raw equality check; a sloppy refactor that .trim()'d here
        // would mask an upstream bug rather than fix it.
        val reason = chatMessageSenderMismatchReason("u-1", " u-1")
        assertEquals(
            "Sender mismatch: queued as u-1, current auth is  u-1",
            reason,
        )
    }

    @Test fun `both empty strings count as a match (defensive)`() {
        // Pin total shape — payload.senderUserId is schema-non-null on
        // the wire so this shouldn't happen, but the gate must not NPE
        // or treat the pathological case as a mismatch.
        assertNull(chatMessageSenderMismatchReason("", ""))
    }

    @Test fun `empty vs non-empty counts as mismatch`() {
        val reason = chatMessageSenderMismatchReason("", "u-1")
        assertEquals("Sender mismatch: queued as , current auth is u-1", reason)
    }
}
