package com.equipseva.app.core.data.repair

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins [RepairJobDto] → [RepairJob] mapping. Heaviest of the DTO
 * mappers because it normalises ~25 fields' worth of legacy/back-compat
 * shapes. Three regions that have repeatedly bitten us:
 *
 *   1) `isAssignedToEngineer` derived from `engineerId` non-blank — the
 *      JobCard composable uses this as the assigned/open gate.
 *   2) Photo arrays default to `emptyList()`, and blank-URL entries are
 *      filtered out so the carousel never paints a 0×0 image.
 *   3) `buildTitle` falls through: first non-blank line → `Job N` →
 *      category display name. Pin the order so a refactor doesn't
 *      promote `Job N` ahead of the issue description.
 */
class RepairJobDtoMapperTest {

    private fun emptyDto(id: String = "j1") = RepairJobDto(id = id)

    @Test fun `minimal dto maps to defaults`() {
        val job = emptyDto().toDomain()
        assertEquals("j1", job.id)
        assertNull(job.jobNumber)
        // No issue line → no jobNumber → falls back to category display
        // name (RepairEquipmentCategory.Other.displayName = "Other").
        assertEquals("Other", job.title)
        assertEquals("", job.issueDescription)
        assertEquals(RepairEquipmentCategory.Other, job.equipmentCategory)
        assertNull(job.equipmentBrand)
        assertNull(job.equipmentModel)
        assertEquals(RepairJobStatus.Unknown, job.status)
        assertEquals(RepairJobUrgency.Unknown, job.urgency)
        assertNull(job.estimatedCostRupees)
        assertNull(job.contractedAmountRupees)
        assertNull(job.scheduledDate)
        assertNull(job.scheduledTimeSlot)
        assertNull(job.siteLocation)
        assertNull(job.siteLatitude)
        assertNull(job.siteLongitude)
        assertFalse(job.isAssignedToEngineer)
        assertNull(job.engineerId)
        assertNull(job.hospitalUserId)
        assertNull(job.startedAtInstant)
        assertNull(job.completedAtInstant)
        assertNull(job.hospitalRating)
        assertNull(job.hospitalReview)
        assertNull(job.engineerRating)
        assertNull(job.engineerReview)
        assertNull(job.createdAtInstant)
        assertNull(job.updatedAtInstant)
        assertTrue(job.issuePhotos.isEmpty())
        assertTrue(job.beforePhotos.isEmpty())
        assertTrue(job.afterPhotos.isEmpty())
        assertFalse(job.isWarrantyCovered)
        assertNull(job.warrantySourceJobId)
        assertNull(job.platformCommissionRupees)
        assertNull(job.engineerPayoutRupees)
        assertNull(job.cancellationReason)
    }

    @Test fun `title — issue first line wins over jobNumber + category`() {
        val job = emptyDto().copy(
            jobNumber = "RJ-001",
            equipmentType = "imaging_radiology",
            issueDescription = "Ultrasound probe arcing intermittently\nSee photo for the burn mark.",
        ).toDomain()
        assertEquals("Ultrasound probe arcing intermittently", job.title)
    }

    @Test fun `title — first non-blank line wins (skips leading blank lines)`() {
        val job = emptyDto().copy(
            issueDescription = "\n   \n   Real issue here\nNoise after that.",
        ).toDomain()
        assertEquals("Real issue here", job.title)
    }

    @Test fun `title — first issue line truncated to 80 chars`() {
        val line = "a".repeat(100)
        val job = emptyDto().copy(issueDescription = line).toDomain()
        assertEquals(80, job.title.length)
    }

    @Test fun `title — jobNumber fallback when issue is blank`() {
        val job = emptyDto().copy(
            jobNumber = "RJ-007",
            issueDescription = "   ",
        ).toDomain()
        assertEquals("Job RJ-007", job.title)
    }

    @Test fun `title — category fallback when issue and jobNumber are blank`() {
        val job = emptyDto().copy(equipmentType = "dental").toDomain()
        assertEquals("Dental", job.title)
    }

    @Test fun `isAssignedToEngineer flips based on engineerId presence and non-blank`() {
        assertFalse(emptyDto().copy(engineerId = null).toDomain().isAssignedToEngineer)
        assertFalse(emptyDto().copy(engineerId = "  ").toDomain().isAssignedToEngineer)
        assertTrue(emptyDto().copy(engineerId = "eng-1").toDomain().isAssignedToEngineer)
    }

    @Test fun `blank engineerId folds to null on the engineerId field too`() {
        val job = emptyDto().copy(engineerId = "   ").toDomain()
        assertNull(job.engineerId)
    }

    @Test fun `negative or zero costs fold to null`() {
        // The KPI surfaces and detail screen show "Quote pending" when
        // estimated cost is null. A 0 (legacy default) was misleading
        // — treat it as null.
        val job = emptyDto().copy(estimatedCost = 0.0, contractedAmountRupees = -1.0).toDomain()
        assertNull(job.estimatedCostRupees)
        assertNull(job.contractedAmountRupees)
    }

    @Test fun `positive cost passes through`() {
        val job = emptyDto().copy(
            estimatedCost = 4500.0,
            contractedAmountRupees = 4200.0,
        ).toDomain()
        assertEquals(4500.0, job.estimatedCostRupees!!, 0.001)
        assertEquals(4200.0, job.contractedAmountRupees!!, 0.001)
    }

    @Test fun `photos — null arrays default to empty list`() {
        val job = emptyDto().toDomain()
        assertTrue(job.issuePhotos.isEmpty())
        assertTrue(job.beforePhotos.isEmpty())
        assertTrue(job.afterPhotos.isEmpty())
    }

    @Test fun `photos — blank URLs are filtered out`() {
        val job = emptyDto().copy(
            issuePhotos = listOf("https://cdn/x1.jpg", "  ", ""),
            beforePhotos = listOf("https://cdn/b1.jpg"),
            afterPhotos = listOf(""),
        ).toDomain()
        assertEquals(listOf("https://cdn/x1.jpg"), job.issuePhotos)
        assertEquals(listOf("https://cdn/b1.jpg"), job.beforePhotos)
        assertTrue(job.afterPhotos.isEmpty())
    }

    @Test fun `ratings — out-of-range values fold to null`() {
        val job = emptyDto().copy(hospitalRating = 0, engineerRating = 7).toDomain()
        assertNull(job.hospitalRating)
        assertNull(job.engineerRating)
    }

    @Test fun `ratings — in-range values pass through`() {
        val job = emptyDto().copy(hospitalRating = 5, engineerRating = 1).toDomain()
        assertEquals(5, job.hospitalRating)
        assertEquals(1, job.engineerRating)
    }

    @Test fun `blank reviews fold to null`() {
        val job = emptyDto().copy(hospitalReview = "  ", engineerReview = "").toDomain()
        assertNull(job.hospitalReview)
        assertNull(job.engineerReview)
    }

    @Test fun `negative commission and payout fold to null but zero passes through`() {
        // Zero is a legitimate value — D12 zeros commission on warranty
        // jobs. A negative would mean a corrupt trigger run; treat it
        // as missing.
        val zero = emptyDto().copy(
            platformCommissionRupees = 0.0,
            engineerPayoutRupees = 0.0,
        ).toDomain()
        assertEquals(0.0, zero.platformCommissionRupees!!, 0.001)
        assertEquals(0.0, zero.engineerPayoutRupees!!, 0.001)

        val negative = emptyDto().copy(
            platformCommissionRupees = -1.0,
            engineerPayoutRupees = -1.0,
        ).toDomain()
        assertNull(negative.platformCommissionRupees)
        assertNull(negative.engineerPayoutRupees)
    }

    @Test fun `equipmentLabel prefers brand + model over category display name`() {
        val job = emptyDto().copy(
            equipmentType = "imaging_radiology",
            equipmentBrand = "GE",
            equipmentModel = "Logiq P5",
        ).toDomain()
        assertEquals("GE Logiq P5", job.equipmentLabel)
    }

    @Test fun `equipmentLabel falls back to category display name when brand and model both blank`() {
        val job = emptyDto().copy(
            equipmentType = "imaging_radiology",
            equipmentBrand = "  ",
            equipmentModel = "",
        ).toDomain()
        assertEquals("Imaging & radiology", job.equipmentLabel)
    }

    @Test fun `equipmentLabel uses brand alone when model is blank`() {
        val job = emptyDto().copy(
            equipmentType = "dental",
            equipmentBrand = "Siemens",
            equipmentModel = " ",
        ).toDomain()
        assertEquals("Siemens", job.equipmentLabel)
    }

    @Test fun `status and urgency known keys round-trip`() {
        val job = emptyDto().copy(status = "completed", urgency = "emergency").toDomain()
        assertEquals(RepairJobStatus.Completed, job.status)
        assertEquals(RepairJobUrgency.Emergency, job.urgency)
    }
}
