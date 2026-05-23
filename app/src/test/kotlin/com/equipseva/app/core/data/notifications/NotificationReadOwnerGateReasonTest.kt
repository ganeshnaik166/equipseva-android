package com.equipseva.app.core.data.notifications

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class NotificationReadOwnerGateReasonTest {

    @Test fun `null queued owner falls through (legacy row, RLS-only)`() {
        // Pin null-owner fallthrough so rows enqueued before the userId
        // field existed still drain. A refactor that always required an
        // owner would poison-drop the entire legacy backlog.
        assertNull(notificationReadOwnerGateReason(queuedOwner = null, currentUserId = null))
        assertNull(notificationReadOwnerGateReason(queuedOwner = null, currentUserId = "u-1"))
    }

    @Test fun `matching owner and current user falls through`() {
        assertNull(notificationReadOwnerGateReason("u-1", "u-1"))
    }

    @Test fun `mismatched owner drops with both ids in the reason`() {
        // Critical pin — shared-device case. A different user is signed
        // in than the one who queued the mark-read; the row must drop
        // before the RPC fires so retry budget isn't burned on a row
        // RLS will reject anyway.
        val reason = notificationReadOwnerGateReason("u-1", "u-2")
        assertEquals("Cross-user notif read drop (queued=u-1, current=u-2)", reason)
    }

    @Test fun `non-null owner with null current user drops (signed out)`() {
        // Pin — signed-out state with a queued owner is still a
        // cross-user mismatch. A refactor that special-cased
        // currentUserId==null to "allow" would let a signed-out drain
        // attempt round-trip the row instead of dropping cleanly.
        val reason = notificationReadOwnerGateReason("u-1", null)
        assertEquals("Cross-user notif read drop (queued=u-1, current=null)", reason)
    }

    @Test fun `blank string owner is treated as a distinct identity (no fallthrough)`() {
        // Defensive — empty string is not null and so does NOT match
        // the null-fallthrough rule. Pin so a future refactor that
        // sloppily treats blanks as null can't accidentally bypass the
        // gate on a malformed payload.
        val reason = notificationReadOwnerGateReason("", "u-1")
        assertEquals("Cross-user notif read drop (queued=, current=u-1)", reason)
    }
}
