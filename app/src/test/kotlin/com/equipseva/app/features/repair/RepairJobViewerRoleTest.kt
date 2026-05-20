package com.equipseva.app.features.repair

import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.core.data.repair.RepairJobUrgency
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * The job-detail screen routes its CTAs based on viewer side: Hospital
 * sees "Accept bid", Engineer sees "Place bid", Other sees the read-only
 * view + the report flow. A misresolved viewerRole either hides CTAs for
 * the right person or surfaces them to a stranger. Pin the precedence
 * chain.
 */
class RepairJobViewerRoleTest {

    @Test fun `null job resolves to Other`() {
        assertEquals(
            RepairJobDetailViewModel.ViewerRole.Other,
            resolveRepairJobViewerRole(null, "u1", null, null, null),
        )
    }

    @Test fun `blank selfId resolves to Other`() {
        assertEquals(
            RepairJobDetailViewModel.ViewerRole.Other,
            resolveRepairJobViewerRole(job("hosp-1"), null, null, null, null),
        )
        assertEquals(
            RepairJobDetailViewModel.ViewerRole.Other,
            resolveRepairJobViewerRole(job("hosp-1"), "", null, null, null),
        )
    }

    @Test fun `matching hospital_user_id wins outright`() {
        // Hospital match short-circuits even if the user also looks like
        // an engineer by every other signal — RLS would reject the bid
        // anyway, and a hospital opening their own posting must see the
        // Accept-bid surface.
        val role = resolveRepairJobViewerRole(
            job = job(hospitalUserId = "u1"),
            selfId = "u1",
            selfEngineerRowId = "eng-1",
            selfProfileRole = "engineer",
            selfActiveRole = "engineer",
        )
        assertEquals(RepairJobDetailViewModel.ViewerRole.Hospital, role)
    }

    @Test fun `engineers row beats profile role and prefs role`() {
        val role = resolveRepairJobViewerRole(
            job = job(hospitalUserId = "hosp-1"),
            selfId = "u2",
            selfEngineerRowId = "eng-9",
            selfProfileRole = null,
            selfActiveRole = null,
        )
        assertEquals(RepairJobDetailViewModel.ViewerRole.Engineer, role)
    }

    @Test fun `profile role engineer counts when engineers row is missing`() {
        // Role-tile signup (PR #225) sets profiles.role but the engineers
        // row only lands after KYC submission. Engineer should still see
        // the Place-bid CTA so they discover the next-step prompt.
        val role = resolveRepairJobViewerRole(
            job = job(hospitalUserId = "hosp-1"),
            selfId = "u2",
            selfEngineerRowId = null,
            selfProfileRole = "engineer",
            selfActiveRole = null,
        )
        assertEquals(RepairJobDetailViewModel.ViewerRole.Engineer, role)
    }

    @Test fun `active role engineer is the last-resort signal`() {
        // Hub-switched persona on this device — neither profile nor
        // engineers row know it yet, but the user's intent is clear.
        val role = resolveRepairJobViewerRole(
            job = job(hospitalUserId = "hosp-1"),
            selfId = "u2",
            selfEngineerRowId = null,
            selfProfileRole = "hospital_admin",
            selfActiveRole = "engineer",
        )
        assertEquals(RepairJobDetailViewModel.ViewerRole.Engineer, role)
    }

    @Test fun `non-engineer signals fall through to Other`() {
        val role = resolveRepairJobViewerRole(
            job = job(hospitalUserId = "hosp-1"),
            selfId = "u2",
            selfEngineerRowId = null,
            selfProfileRole = "supplier",
            selfActiveRole = "supplier",
        )
        assertEquals(RepairJobDetailViewModel.ViewerRole.Other, role)
    }

    @Test fun `blank engineers row id is treated as absent`() {
        val role = resolveRepairJobViewerRole(
            job = job(hospitalUserId = "hosp-1"),
            selfId = "u2",
            selfEngineerRowId = "  ",
            selfProfileRole = null,
            selfActiveRole = null,
        )
        assertEquals(RepairJobDetailViewModel.ViewerRole.Other, role)
    }

    private fun job(hospitalUserId: String?) = RepairJob(
        id = "job-1",
        jobNumber = "RJ-001",
        title = "x",
        issueDescription = "x",
        equipmentCategory = RepairEquipmentCategory.Other,
        equipmentBrand = null,
        equipmentModel = null,
        status = RepairJobStatus.Requested,
        urgency = RepairJobUrgency.Scheduled,
        estimatedCostRupees = null,
        scheduledDate = null,
        scheduledTimeSlot = null,
        siteLocation = null,
        isAssignedToEngineer = false,
        engineerId = null,
        hospitalUserId = hospitalUserId,
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
