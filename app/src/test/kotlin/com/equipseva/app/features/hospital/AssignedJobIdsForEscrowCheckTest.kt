package com.equipseva.app.features.hospital

import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.core.data.repair.RepairJobUrgency
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the r1509 "Awaiting payment" escrow-check slice: only Assigned jobs
 * are candidates (accept flips Requested → Assigned; payment flips the escrow
 * pending → held while the job STAYS Assigned until check-in), and the list
 * is capped as an N+1 safety valve.
 */
class AssignedJobIdsForEscrowCheckTest {

    private fun job(id: String, status: RepairJobStatus) = RepairJob(
        id = id,
        jobNumber = null,
        title = "t",
        issueDescription = "i",
        equipmentCategory = RepairEquipmentCategory.PatientMonitoring,
        equipmentBrand = null,
        equipmentModel = null,
        status = status,
        urgency = RepairJobUrgency.Scheduled,
        estimatedCostRupees = null,
        scheduledDate = null,
        scheduledTimeSlot = null,
        siteLocation = null,
        isAssignedToEngineer = status != RepairJobStatus.Requested,
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

    @Test fun `only Assigned jobs are checked`() {
        val ids = assignedJobIdsForEscrowCheck(
            listOf(
                job("a", RepairJobStatus.Requested),
                job("b", RepairJobStatus.Assigned),
                job("c", RepairJobStatus.EnRoute),
                job("d", RepairJobStatus.InProgress),
                job("e", RepairJobStatus.Completed),
                job("f", RepairJobStatus.Assigned),
            ),
        )
        assertEquals(listOf("b", "f"), ids)
    }

    @Test fun `capped at five as the N+1 safety valve`() {
        val many = (1..9).map { job("j$it", RepairJobStatus.Assigned) }
        assertEquals(5, assignedJobIdsForEscrowCheck(many).size)
    }

    @Test fun `no Assigned jobs means no lookups`() {
        assertEquals(
            emptyList<String>(),
            assignedJobIdsForEscrowCheck(listOf(job("a", RepairJobStatus.Requested))),
        )
    }
}
