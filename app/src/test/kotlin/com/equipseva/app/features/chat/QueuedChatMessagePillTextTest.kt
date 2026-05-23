package com.equipseva.app.features.chat

import com.equipseva.app.features.mybids.queuedBidPillText
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the queued-chat-message pill text. Critical cross-surface
 * invariant: chat says "message / send" while mybids says "bid /
 * submit". The two helpers MUST stay separate to preserve the
 * surface-specific vocabulary.
 */
class QueuedChatMessagePillTextTest {

    @Test fun `count of 1 reads singular`() {
        assertEquals(
            "1 message queued — will send when back online",
            queuedChatMessagePillText(1),
        )
    }

    @Test fun `count of 2 reads plural`() {
        assertEquals(
            "2 messages queued — will send when back online",
            queuedChatMessagePillText(2),
        )
    }

    @Test fun `count of 0 reads plural shape (defensive)`() {
        assertEquals(
            "0 messages queued — will send when back online",
            queuedChatMessagePillText(0),
        )
    }

    @Test fun `large count interpolates with plural`() {
        assertEquals(
            "42 messages queued — will send when back online",
            queuedChatMessagePillText(42),
        )
    }

    @Test fun `em-dash separator is U+2014 not en-dash`() {
        val text = queuedChatMessagePillText(1)
        assertTrue(text.contains('—'))
        assertEquals(false, text.contains('–'))
    }

    @Test fun `cross-surface invariant — chat vocab differs from mybids vocab`() {
        // Pin the asymmetry. A refactor that unified the two via
        // a parametric helper would risk leaking the wrong noun
        // ("bid" on chat, "message" on mybids).
        val chatText = queuedChatMessagePillText(1)
        val bidText = queuedBidPillText(1)
        assertNotEquals(chatText, bidText)
        assertTrue(chatText.contains("message"))
        assertTrue(bidText.contains("bid"))
        assertTrue(chatText.contains("send"))
        assertTrue(bidText.contains("submit"))
    }
}
