package com.equipseva.app.features.activework

import com.equipseva.app.features.chat.queuedChatMessagePillText
import com.equipseva.app.features.mybids.queuedBidPillText
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins queuedStatusChangePillText AND the cross-surface vocabulary
 * triad — three offline-queue pills in the app, three different
 * verbs that MUST stay distinct.
 */
class QueuedStatusChangePillTextTest {

    @Test fun `count of 1 reads singular`() {
        assertEquals(
            "1 status change queued — will sync when back online",
            queuedStatusChangePillText(1),
        )
    }

    @Test fun `count of 2 reads plural`() {
        assertEquals(
            "2 status changes queued — will sync when back online",
            queuedStatusChangePillText(2),
        )
    }

    @Test fun `singular drops the s on change (not status changes)`() {
        // Critical pin — "1 status change" not "1 status changes".
        val out = queuedStatusChangePillText(1)
        assertTrue(out.contains("1 status change "))
        assertEquals(false, out.contains("1 status changes "))
    }

    @Test fun `plural keeps the s on changes`() {
        val out = queuedStatusChangePillText(5)
        assertTrue(out.contains("5 status changes "))
    }

    @Test fun `count of 0 reads plural shape (defensive — caller gates)`() {
        assertEquals(
            "0 status changes queued — will sync when back online",
            queuedStatusChangePillText(0),
        )
    }

    @Test fun `em-dash separator is U+2014`() {
        assertTrue(queuedStatusChangePillText(1).contains('—'))
    }

    @Test fun `cross-surface vocab triad — submit-send-sync stay distinct`() {
        // Pin the three-way vocabulary asymmetry. A unifying refactor
        // would risk leaking the wrong verb on at least two surfaces.
        val bid = queuedBidPillText(1)
        val msg = queuedChatMessagePillText(1)
        val sts = queuedStatusChangePillText(1)
        assertNotEquals(bid, msg)
        assertNotEquals(msg, sts)
        assertNotEquals(bid, sts)
        assertTrue(bid.contains("submit"))
        assertTrue(msg.contains("send"))
        assertTrue(sts.contains("sync"))
    }

    @Test fun `cross-surface noun triad — bid-message-status stay distinct`() {
        val bid = queuedBidPillText(1)
        val msg = queuedChatMessagePillText(1)
        val sts = queuedStatusChangePillText(1)
        assertTrue(bid.contains("bid"))
        assertTrue(msg.contains("message"))
        assertTrue(sts.contains("status"))
    }
}
