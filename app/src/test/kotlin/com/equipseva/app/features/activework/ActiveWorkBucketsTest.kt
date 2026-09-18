package com.equipseva.app.features.activework

import com.equipseva.app.core.data.repair.RepairJobStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the engineer Active-work bucketing.
 *
 * The screen renders `activeJobs + completedJobs` and nothing else, so
 * a status in NEITHER bucket is a job the engineer cannot reach at all
 * — the list is their only route to the detail screen.
 */
class ActiveWorkBucketsTest {

    @Test fun `assigned en route and in progress are active work`() {
        // Assigned included so the job appears the moment a hospital
        // accepts the bid; without it the engineer had no entry point
        // until check-in, which they could only do from this screen.
        assertTrue(isActiveWorkJob(RepairJobStatus.Assigned))
        assertTrue(isActiveWorkJob(RepairJobStatus.EnRoute))
        assertTrue(isActiveWorkJob(RepairJobStatus.InProgress))
    }

    @Test fun `completed and cancelled are closed`() {
        assertTrue(isClosedWorkJob(RepairJobStatus.Completed))
        assertTrue(isClosedWorkJob(RepairJobStatus.Cancelled))
    }

    @Test fun `disputed is closed, not invisible`() {
        // Critical pin. The server allows completed -> disputed, the
        // detail screen renders the dispute banner plus the engineer's
        // "Respond to dispute" action, and the hospital's own list
        // already files Disputed under closed. Matching neither bucket
        // dropped the job off the engineer's list at exactly the moment
        // they had an admin review window to answer in.
        assertTrue(isClosedWorkJob(RepairJobStatus.Disputed))
        assertFalse("a disputed job is not in-progress work", isActiveWorkJob(RepairJobStatus.Disputed))
    }

    @Test fun `every real status lands in exactly one bucket`() {
        // The structural pin: adding a status to the enum without
        // bucketing it here makes jobs vanish from the engineer's only
        // list, which is how Disputed was lost. Unknown is excluded —
        // it is the client's parse fallback, not a server state.
        //
        // Do not widen this exclusion list to make the sweep pass. Every
        // other status can arrive on this screen, because the query behind
        // it filters on engineer_id with no status filter at all.
        val unbucketed = RepairJobStatus.entries
            .filter { it != RepairJobStatus.Unknown }
            .filter { !isActiveWorkJob(it) && !isClosedWorkJob(it) }
        assertEquals("statuses in no bucket are unreachable jobs", emptyList<RepairJobStatus>(), unbucketed)

        val doubleBucketed = RepairJobStatus.entries
            .filter { isActiveWorkJob(it) && isClosedWorkJob(it) }
        assertEquals("a status in both buckets renders twice", emptyList<RepairJobStatus>(), doubleBucketed)
    }

    @Test fun `the unknown parse fallback is in neither bucket`() {
        assertFalse(isActiveWorkJob(RepairJobStatus.Unknown))
        assertFalse(isClosedWorkJob(RepairJobStatus.Unknown))
    }

    @Test fun `a pre-assigned visit still marked requested is active work`() {
        // The assigned-to-me query filters on engineer_id and nothing else,
        // so a visit pre-assigned to this engineer rather than bid on
        // arrives here still marked requested. Production holds such a row.
        // Treating it as unbucketed dropped it off the engineer's only list.
        assertTrue(isActiveWorkJob(RepairJobStatus.Requested))
        assertFalse("a job still waiting to start is not closed", isClosedWorkJob(RepairJobStatus.Requested))
    }
}
