package com.equipseva.app.features.hospital

import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.core.data.repair.RepairJobUrgency
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the hospital active-jobs filter projection. Three lists (open /
 * in-progress / closed) are already bucketed server-side; the UiState
 * derives `visibleJobs` based on the four-way filter chip selection.
 * A regression in the projection would either silently hide rows from
 * a filtered tab or double-render rows under "All".
 */
class HospitalActiveJobsUiStateTest {

    private fun job(id: String) = RepairJob(
        id = id,
        jobNumber = null,
        title = "Repair $id",
        issueDescription = "",
        equipmentCategory = RepairEquipmentCategory.Other,
        equipmentBrand = null,
        equipmentModel = null,
        status = RepairJobStatus.Unknown,
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

    private fun state(filter: HospitalActiveJobsViewModel.Filter) =
        HospitalActiveJobsViewModel.UiState(
            loading = false,
            openJobs = listOf(job("o1"), job("o2")),
            inProgressJobs = listOf(job("p1")),
            closedJobs = listOf(job("c1"), job("c2"), job("c3")),
            filter = filter,
        )

    @Test fun `All filter concatenates open then in-progress then closed`() {
        val s = state(HospitalActiveJobsViewModel.Filter.All)
        // Order matters — the UI relies on open jobs surfacing first so
        // hospital users see actionable rows above the closed history.
        assertEquals(
            listOf("o1", "o2", "p1", "c1", "c2", "c3"),
            s.visibleJobs.map { it.id },
        )
    }

    @Test fun `Open filter shows only open jobs`() {
        val s = state(HospitalActiveJobsViewModel.Filter.Open)
        assertEquals(listOf("o1", "o2"), s.visibleJobs.map { it.id })
    }

    @Test fun `Active filter shows only in-progress jobs`() {
        val s = state(HospitalActiveJobsViewModel.Filter.Active)
        assertEquals(listOf("p1"), s.visibleJobs.map { it.id })
    }

    @Test fun `Closed filter shows only closed jobs`() {
        val s = state(HospitalActiveJobsViewModel.Filter.Closed)
        assertEquals(listOf("c1", "c2", "c3"), s.visibleJobs.map { it.id })
    }

    @Test fun `empty buckets project to empty visibleJobs`() {
        val s = HospitalActiveJobsViewModel.UiState(
            loading = false,
            filter = HospitalActiveJobsViewModel.Filter.All,
        )
        assertEquals(emptyList<RepairJob>(), s.visibleJobs)
    }
}
