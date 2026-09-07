package com.equipseva.app.features.repair

import com.equipseva.app.core.data.repair.RepairBid
import com.equipseva.app.core.data.repair.RepairBidStatus
import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.core.data.repair.RepairJobUrgency
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * round3817 — pins the "is THIS engineer the assigned one" decision that
 * gates the on-site CTAs (Check in / Mark done / Revise quote / Cancel)
 * on the repair-job detail screen. Before this, any engineer opening an
 * Assigned job saw "Check in on-site" and got a server 42501 — safe but
 * misleading, and it hid the real state of the job from them.
 */
class IsViewerAssignedEngineerTest {

    private fun job(engineerId: String?) = RepairJob(
        id = "j1",
        jobNumber = "RPR-00040",
        title = "Repair",
        issueDescription = "",
        equipmentCategory = RepairEquipmentCategory.Other,
        equipmentBrand = null,
        equipmentModel = null,
        status = RepairJobStatus.Assigned,
        urgency = RepairJobUrgency.Unknown,
        estimatedCostRupees = null,
        scheduledDate = null,
        scheduledTimeSlot = null,
        siteLocation = null,
        isAssignedToEngineer = engineerId != null,
        engineerId = engineerId,
        hospitalUserId = "h-1",
        startedAtInstant = null,
        completedAtInstant = null,
        hospitalRating = null,
        hospitalReview = null,
        engineerRating = null,
        engineerReview = null,
        createdAtInstant = null,
        updatedAtInstant = null,
    )

    private fun bid(status: RepairBidStatus) = RepairBid(
        id = "b1",
        repairJobId = "j1",
        engineerUserId = "u-1",
        amountRupees = 2500.0,
        etaHours = 4,
        note = null,
        status = status,
        createdAtInstant = null,
        updatedAtInstant = null,
    )

    @Test fun `assigned engineer by engineers row id`() {
        assertTrue(isViewerAssignedEngineer(job("eng-A"), selfEngineerRowId = "eng-A", ownBid = null))
    }

    @Test fun `AMC-style pre-assignment without any bid still counts`() {
        // AMC visit jobs are assigned server-side; there is no repair bid to
        // fall back on, so the engineers-row match must be sufficient alone.
        assertTrue(isViewerAssignedEngineer(job("eng-A"), selfEngineerRowId = "eng-A", ownBid = null))
        assertFalse(isViewerAssignedEngineer(job("eng-A"), selfEngineerRowId = "eng-B", ownBid = null))
    }

    @Test fun `accepted own bid counts even when the engineers row could not be fetched`() {
        assertTrue(isViewerAssignedEngineer(job("eng-A"), selfEngineerRowId = null, ownBid = bid(RepairBidStatus.Accepted)))
    }

    @Test fun `another engineer viewing an assigned job is NOT assigned`() {
        // The exact defect: engineer B opens engineer A's Assigned job.
        assertFalse(isViewerAssignedEngineer(job("eng-A"), selfEngineerRowId = "eng-B", ownBid = null))
        assertFalse(isViewerAssignedEngineer(job("eng-A"), selfEngineerRowId = "eng-B", ownBid = bid(RepairBidStatus.Rejected)))
        assertFalse(isViewerAssignedEngineer(job("eng-A"), selfEngineerRowId = "eng-B", ownBid = bid(RepairBidStatus.Pending)))
    }

    @Test fun `no engineer on the job means nobody is assigned`() {
        assertFalse(isViewerAssignedEngineer(job(null), selfEngineerRowId = "eng-A", ownBid = null))
        assertFalse(isViewerAssignedEngineer(job(""), selfEngineerRowId = "", ownBid = null))
    }

    @Test fun `blank ids never match each other`() {
        // Guards the degenerate "" == "" case: a job with a blank engineerId
        // must not light up the CTA for an engineer with a blank row id.
        assertFalse(isViewerAssignedEngineer(job(""), selfEngineerRowId = "", ownBid = bid(RepairBidStatus.Pending)))
    }
}
