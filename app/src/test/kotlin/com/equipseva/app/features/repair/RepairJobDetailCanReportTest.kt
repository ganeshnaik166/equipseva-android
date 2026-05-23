package com.equipseva.app.features.repair

import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.core.data.repair.RepairJobUrgency
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the report-CTA visibility gate on the repair-job detail
 * screen. The "Report this job" affordance shouldn't show to the
 * hospital who posted the job — they're the counterparty being
 * reported, not the reporter. A regression that flipped the check
 * would either remove the report CTA for engineers (defeating the
 * trust + safety surface) or surface it to hospitals (letting them
 * report their own job).
 */
class RepairJobDetailCanReportTest {

    private fun job(id: String = "j1") = RepairJob(
        id = id,
        jobNumber = null,
        title = "Repair",
        issueDescription = "",
        equipmentCategory = RepairEquipmentCategory.Other,
        equipmentBrand = null,
        equipmentModel = null,
        status = RepairJobStatus.Requested,
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

    @Test fun `canReport false when job is null (still loading)`() {
        val state = RepairJobDetailViewModel.RepairJobDetailUiState(
            viewerRole = RepairJobDetailViewModel.ViewerRole.Engineer,
            job = null,
        )
        assertFalse(state.canReport)
    }

    @Test fun `canReport false when viewer is the Hospital who posted it`() {
        val state = RepairJobDetailViewModel.RepairJobDetailUiState(
            viewerRole = RepairJobDetailViewModel.ViewerRole.Hospital,
            job = job(),
        )
        assertFalse(state.canReport)
    }

    @Test fun `canReport true when viewer is Engineer`() {
        val state = RepairJobDetailViewModel.RepairJobDetailUiState(
            viewerRole = RepairJobDetailViewModel.ViewerRole.Engineer,
            job = job(),
        )
        assertTrue(state.canReport)
    }

    @Test fun `canReport true when viewer is Other such as founder`() {
        // Founder / admin views aren't first-class but shouldn't be
        // blocked from filing a report either.
        val state = RepairJobDetailViewModel.RepairJobDetailUiState(
            viewerRole = RepairJobDetailViewModel.ViewerRole.Other,
            job = job(),
        )
        assertTrue(state.canReport)
    }
}
