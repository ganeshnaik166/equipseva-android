package com.equipseva.app.features.chat

import com.equipseva.app.testing.FakeRest
import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.IOException

/**
 * Pins where a failed chat message's text goes.
 *
 * `onSend` clears the composer before the network call, so the typed
 * text survives only where this decision sends it. The old behaviour
 * enqueued EVERY failure: on a 4xx the user saw the real error plus a
 * "1 message queued — will send when back online" pill, the outbox then
 * dropped the row permanently, and the message was gone with no copy
 * anywhere.
 */
class ChatSendRecoveryTest {

    @Test fun `an outage queues the message and leaves the composer empty`() {
        assertEquals(
            ChatSendRecovery.QueueForRetry,
            chatSendRecovery(IOException("no route to host")),
        )
    }

    @Test fun `a closed conversation restores the draft and queues nothing`() {
        // The chat_messages_block_on_completed_job trigger raises
        // chat_conversation_closed once the repair job ends. It will
        // never succeed on retry, so queueing is pure loss.
        assertEquals(
            ChatSendRecovery.RestoreDraft,
            chatSendRecovery(FakeRest.rest(400, "chat_conversation_closed")),
        )
    }

    @Test fun `an RLS denial restores the draft`() {
        assertEquals(
            ChatSendRecovery.RestoreDraft,
            chatSendRecovery(FakeRest.rest(403, "new row violates row-level security policy")),
        )
    }

    @Test fun `a rate limit restores the draft rather than promising a send`() {
        // Deliberate: chat_rate_limited_* has real user-facing copy
        // ("wait a moment, then try again"), which is only actionable if
        // the text is still in front of the user.
        assertEquals(
            ChatSendRecovery.RestoreDraft,
            chatSendRecovery(FakeRest.rest(429, "chat_rate_limited_user")),
        )
    }

    @Test fun `a body-too-long refusal restores the draft so it can be shortened`() {
        assertEquals(
            ChatSendRecovery.RestoreDraft,
            chatSendRecovery(FakeRest.rest(400, "value too long for type character varying")),
        )
    }
}
