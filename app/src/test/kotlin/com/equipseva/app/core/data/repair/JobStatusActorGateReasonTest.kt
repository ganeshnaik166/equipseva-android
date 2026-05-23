package com.equipseva.app.core.data.repair

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class JobStatusActorGateReasonTest {

    @Test fun `null queued actor drops with legacy refusal (STRICT policy)`() {
        // CRITICAL pin — strict policy. Job-status flips affect server
        // state (escrow release, AMC ledger, ratings hook) so we will
        // NOT drain a legacy null-actor row under whichever user is
        // signed in. A sign-out → sign-in-as-someone-else cycle would
        // otherwise let the new user complete the old user's job.
        //
        // Asymmetric vs RepairBidOutboxHandler + NotificationReadOutbox
        // which fall through on null. Pin the asymmetry — a refactor
        // that unified them would silently break T&S here.
        assertEquals(
            "Missing actorUserId on legacy payload — refusing to drain",
            jobStatusActorGateReason(queuedActorUserId = null, currentUserId = "u-1"),
        )
    }

    @Test fun `matching actor falls through`() {
        assertNull(jobStatusActorGateReason("u-1", "u-1"))
    }

    @Test fun `mismatch drops with both ids and 'Actor mismatch' prefix`() {
        // Shared-device case. Prefix "Actor mismatch:" is wire-frozen
        // for ops log filters; pin so a refactor doesn't accidentally
        // rename it.
        val reason = jobStatusActorGateReason("u-1", "u-2")
        assertEquals("Actor mismatch: queued as u-1, current auth is u-2", reason)
    }

    @Test fun `legacy reason prefix is wire-frozen verbatim`() {
        // Defensive pin — the exact reason string surfaces in the ops
        // log filter and in the poison-drop notification body. A
        // refactor that paraphrased it would break log filters.
        val reason = jobStatusActorGateReason(null, "anything")
        assertEquals("Missing actorUserId on legacy payload — refusing to drain", reason)
    }

    @Test fun `case-sensitive comparison`() {
        val reason = jobStatusActorGateReason(
            "ABCDEF00-0000-0000-0000-000000000001",
            "abcdef00-0000-0000-0000-000000000001",
        )
        assertEquals(
            "Actor mismatch: queued as ABCDEF00-0000-0000-0000-000000000001, " +
                "current auth is abcdef00-0000-0000-0000-000000000001",
            reason,
        )
    }

    @Test fun `blank string queued actor is mismatch (not legacy null)`() {
        // Pin — empty string is not null. Defensive against a refactor
        // that maps blanks to null and accidentally takes the legacy
        // path (which has different copy + future-only meaning).
        val reason = jobStatusActorGateReason("", "u-1")
        assertEquals("Actor mismatch: queued as , current auth is u-1", reason)
    }
}
