package com.equipseva.app.core.data.repair

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class RepairBidEngineerGateReasonTest {

    @Test fun `null queued engineer falls through (legacy row, RLS-only)`() {
        // Pin lenient policy — rows enqueued before the owner-gate
        // plumbing landed still drain via RLS on engineer_user_id. A
        // refactor that unified with the strict job-status gate would
        // poison-drop the entire legacy bid backlog.
        assertNull(repairBidEngineerGateReason(queuedEngineerUserId = null, currentUserId = "u-1"))
    }

    @Test fun `matching engineer falls through`() {
        assertNull(repairBidEngineerGateReason("u-1", "u-1"))
    }

    @Test fun `mismatch drops with both ids and 'Engineer mismatch' prefix`() {
        // Critical pin — shared-device case. User B is signed in but
        // user A's bid is queued. The handler drops the row before the
        // RPC fires so user B can't accidentally bid under user A's id.
        // Prefix "Engineer mismatch:" is wire-frozen for ops log
        // filters; pin so a refactor doesn't accidentally rename it.
        val reason = repairBidEngineerGateReason("u-1", "u-2")
        assertEquals("Engineer mismatch: queued as u-1, current auth is u-2", reason)
    }

    @Test fun `case-sensitive comparison (UUIDs lowercase on wire)`() {
        // Pin — a refactor that lowercased one side would silently
        // start dropping its own queued bids if the persistence layer
        // ever started writing uppercase.
        val reason = repairBidEngineerGateReason(
            "ABCDEF00-0000-0000-0000-000000000001",
            "abcdef00-0000-0000-0000-000000000001",
        )
        assertEquals(
            "Engineer mismatch: queued as ABCDEF00-0000-0000-0000-000000000001, " +
                "current auth is abcdef00-0000-0000-0000-000000000001",
            reason,
        )
    }

    @Test fun `blank string queued engineer is treated as a distinct id (not null)`() {
        // Defensive — empty string is not null and does NOT trigger
        // the legacy-fallthrough rule. Pin so a sloppy refactor that
        // maps blanks to null can't accidentally bypass the gate on a
        // malformed payload.
        val reason = repairBidEngineerGateReason("", "u-1")
        assertEquals("Engineer mismatch: queued as , current auth is u-1", reason)
    }
}
