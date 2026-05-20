package com.equipseva.app.features.hospital

import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.core.data.repair.RepairJobUrgency
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the two pure pieces of [HospitalActiveJobsViewModel]:
 *  1. [partitionHospitalJobs] — the three-way status split the screen
 *     surfaces (open / in-progress / closed).
 *  2. [HospitalActiveJobsViewModel.UiState.visibleJobs] — the chip-filter
 *     derived view the LazyColumn renders. A regression here either drops
 *     a chip (e.g. Completed silently hides cancelled jobs) or merges
 *     buckets wrong on the All chip.
 */
class HospitalActiveJobsUiStateTest {

    // ---- partition --------------------------------------------------------

    @Test fun `partition empty list returns three empty lists`() {
        val (open, inProgress, closed) = partitionHospitalJobs(emptyList())
        assertTrue(open.isEmpty())
        assertTrue(inProgress.isEmpty())
        assertTrue(closed.isEmpty())
    }

    @Test fun `Requested goes to open only`() {
        val r = job("r", RepairJobStatus.Requested)
        val (open, inProgress, closed) = partitionHospitalJobs(listOf(r))
        assertEquals(listOf(r), open)
        assertTrue(inProgress.isEmpty())
        assertTrue(closed.isEmpty())
    }

    @Test fun `Assigned, EnRoute, InProgress all land in inProgress bucket`() {
        val a = job("a", RepairJobStatus.Assigned)
        val e = job("e", RepairJobStatus.EnRoute)
        val p = job("p", RepairJobStatus.InProgress)
        val (open, inProgress, closed) = partitionHospitalJobs(listOf(a, e, p))
        assertTrue(open.isEmpty())
        assertEquals(listOf(a, e, p), inProgress)
        assertTrue(closed.isEmpty())
    }

    @Test fun `Completed, Cancelled, Disputed all land in closed bucket`() {
        // Disputed sits in closed deliberately — the dispute flow lives
        // elsewhere; from the feed the work is over.
        val done = job("c", RepairJobStatus.Completed)
        val cancel = job("x", RepairJobStatus.Cancelled)
        val dispute = job("d", RepairJobStatus.Disputed)
        val (open, inProgress, closed) = partitionHospitalJobs(listOf(done, cancel, dispute))
        assertTrue(open.isEmpty())
        assertTrue(inProgress.isEmpty())
        assertEquals(listOf(done, cancel, dispute), closed)
    }

    @Test fun `partition silently drops Unknown statuses`() {
        // Server may add a new status tomorrow — we never crash, we just
        // hide the row from every bucket.
        val u = job("u", RepairJobStatus.Unknown)
        val (open, inProgress, closed) = partitionHospitalJobs(listOf(u))
        assertTrue(open.isEmpty())
        assertTrue(inProgress.isEmpty())
        assertTrue(closed.isEmpty())
    }

    // ---- visibleJobs filter chip ------------------------------------------

    @Test fun `visibleJobs on All concatenates open + inProgress + closed in that order`() {
        val o = job("o", RepairJobStatus.Requested)
        val p = job("p", RepairJobStatus.InProgress)
        val c = job("c", RepairJobStatus.Completed)
        val state = state(open = listOf(o), inProgress = listOf(p), closed = listOf(c))
        // Order matters: the screen renders top→bottom in this sequence so
        // open jobs always sit at the top of the All view.
        assertEquals(listOf(o, p, c), state.visibleJobs)
    }

    @Test fun `visibleJobs on Open returns only open bucket`() {
        val o = job("o", RepairJobStatus.Requested)
        val p = job("p", RepairJobStatus.InProgress)
        val c = job("c", RepairJobStatus.Completed)
        val state = state(
            open = listOf(o),
            inProgress = listOf(p),
            closed = listOf(c),
            filter = HospitalActiveJobsViewModel.Filter.Open,
        )
        assertEquals(listOf(o), state.visibleJobs)
    }

    @Test fun `visibleJobs on Active returns only inProgress bucket`() {
        val o = job("o", RepairJobStatus.Requested)
        val p = job("p", RepairJobStatus.InProgress)
        val c = job("c", RepairJobStatus.Completed)
        val state = state(
            open = listOf(o),
            inProgress = listOf(p),
            closed = listOf(c),
            filter = HospitalActiveJobsViewModel.Filter.Active,
        )
        assertEquals(listOf(p), state.visibleJobs)
    }

    @Test fun `visibleJobs on Completed only shows Completed, hiding Cancelled and Disputed`() {
        // The Completed chip is narrower than the closed bucket: it strips
        // out Cancelled and Disputed rows so the hospital sees only jobs
        // that actually resolved.
        val done = job("done", RepairJobStatus.Completed)
        val cancel = job("x", RepairJobStatus.Cancelled)
        val dispute = job("d", RepairJobStatus.Disputed)
        val state = state(
            closed = listOf(done, cancel, dispute),
            filter = HospitalActiveJobsViewModel.Filter.Completed,
        )
        assertEquals(listOf(done), state.visibleJobs)
    }

    @Test fun `visibleJobs is empty when all buckets are empty regardless of filter`() {
        val empty = state()
        for (f in HospitalActiveJobsViewModel.Filter.entries) {
            assertTrue(
                "filter $f should produce empty list",
                empty.copy(filter = f).visibleJobs.isEmpty(),
            )
        }
    }

    // ---- helpers ----------------------------------------------------------

    private fun state(
        open: List<RepairJob> = emptyList(),
        inProgress: List<RepairJob> = emptyList(),
        closed: List<RepairJob> = emptyList(),
        filter: HospitalActiveJobsViewModel.Filter = HospitalActiveJobsViewModel.Filter.All,
    ) = HospitalActiveJobsViewModel.UiState(
        loading = false,
        refreshing = false,
        openJobs = open,
        inProgressJobs = inProgress,
        closedJobs = closed,
        errorMessage = null,
        filter = filter,
    )

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
