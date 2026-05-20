package com.equipseva.app.features.activework

import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.core.data.repair.RepairJobUrgency
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins [partitionEngineerJobs] — the pure split the engineer-side
 * "Active Work" feed runs over their assigned-jobs list. A regression here
 * either drops Assigned jobs (engineer can't see a freshly-accepted bid)
 * or leaks Requested / Disputed rows into the active/completed sections.
 */
class ActiveWorkPartitionTest {

    @Test fun `empty input yields two empty lists`() {
        val (active, completed) = partitionEngineerJobs(emptyList())
        assertTrue(active.isEmpty())
        assertTrue(completed.isEmpty())
    }

    @Test fun `active bucket includes Assigned, EnRoute, InProgress`() {
        val a = job("a", RepairJobStatus.Assigned)
        val b = job("b", RepairJobStatus.EnRoute)
        val c = job("c", RepairJobStatus.InProgress)
        val (active, completed) = partitionEngineerJobs(listOf(a, b, c))
        assertEquals(listOf(a, b, c), active)
        assertTrue(completed.isEmpty())
    }

    @Test fun `completed bucket includes Completed and Cancelled`() {
        val done = job("done", RepairJobStatus.Completed)
        val gone = job("gone", RepairJobStatus.Cancelled)
        val (active, completed) = partitionEngineerJobs(listOf(done, gone))
        assertTrue(active.isEmpty())
        assertEquals(listOf(done, gone), completed)
    }

    @Test fun `Requested, Disputed, Unknown land in neither bucket`() {
        // Engineer's assigned feed should never carry these from server, but
        // if it does we silently drop them — neither active nor done.
        val open = job("open", RepairJobStatus.Requested)
        val disputed = job("disp", RepairJobStatus.Disputed)
        val unknown = job("unk", RepairJobStatus.Unknown)
        val (active, completed) = partitionEngineerJobs(listOf(open, disputed, unknown))
        assertTrue(active.isEmpty())
        assertTrue(completed.isEmpty())
    }

    @Test fun `mixed list preserves input order within each bucket`() {
        val a1 = job("a1", RepairJobStatus.Assigned)
        val d1 = job("d1", RepairJobStatus.Completed)
        val a2 = job("a2", RepairJobStatus.InProgress)
        val d2 = job("d2", RepairJobStatus.Cancelled)
        val (active, completed) = partitionEngineerJobs(listOf(a1, d1, a2, d2))
        // Filter preserves source order — important for the screen because the
        // feed is already sorted server-side by recency.
        assertEquals(listOf(a1, a2), active)
        assertEquals(listOf(d1, d2), completed)
    }

    private fun job(id: String, status: RepairJobStatus) = RepairJob(
        id = id,
        jobNumber = null,
        title = "t",
        issueDescription = "i",
        equipmentCategory = RepairEquipmentCategory.Other,
        equipmentBrand = null,
        equipmentModel = null,
        status = status,
        urgency = RepairJobUrgency.Unknown,
        estimatedCostRupees = null,
        scheduledDate = null,
        scheduledTimeSlot = null,
        siteLocation = null,
        isAssignedToEngineer = false,
        engineerId = null,
        hospitalUserId = null,
        startedAtInstant = null,
        completedAtInstant = null,
        hospitalRating = null,
        hospitalReview = null,
        engineerRating = null,
        engineerReview = null,
        createdAtInstant = null,
        updatedAtInstant = null,
    )
}
