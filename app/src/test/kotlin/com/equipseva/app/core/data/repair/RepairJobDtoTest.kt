package com.equipseva.app.core.data.repair

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

/**
 * The domain mapper does most of the defensive work — blank fields collapse
 * to null, ratings clamp to 1..5, photo URLs drop blanks, equipment falls
 * back to Other, costs <= 0 collapse to null. The screen layer relies on
 * these invariants to skip "null check + blank check" everywhere.
 */
class RepairJobDtoTest {

    @Test fun `blank fields collapse to null in the domain model`() {
        val dto = dto(
            equipmentBrand = "   ",
            equipmentModel = "",
            scheduledDate = "  ",
            scheduledTimeSlot = "",
            siteLocation = " ",
            hospitalUserId = "",
            engineerId = "",
            hospitalReview = "  ",
            engineerReview = "",
        )

        val domain = dto.toDomain()
        assertNull(domain.equipmentBrand)
        assertNull(domain.equipmentModel)
        assertNull(domain.scheduledDate)
        assertNull(domain.scheduledTimeSlot)
        assertNull(domain.siteLocation)
        assertNull(domain.hospitalUserId)
        assertNull(domain.engineerId)
        assertNull(domain.hospitalReview)
        assertNull(domain.engineerReview)
    }

    @Test fun `engineerId blank means unassigned`() {
        val domain = dto(engineerId = "").toDomain()
        assertFalse(domain.isAssignedToEngineer)
    }

    @Test fun `engineerId non-blank means assigned`() {
        val domain = dto(engineerId = "eng-1").toDomain()
        assertTrue(domain.isAssignedToEngineer)
        assertEquals("eng-1", domain.engineerId)
    }

    @Test fun `negative or zero costs degrade to null`() {
        val zero = dto(estimatedCost = 0.0, contractedAmountRupees = 0.0).toDomain()
        assertNull(zero.estimatedCostRupees)
        assertNull(zero.contractedAmountRupees)

        val negative = dto(estimatedCost = -1.0, contractedAmountRupees = -10.0).toDomain()
        assertNull(negative.estimatedCostRupees)
        assertNull(negative.contractedAmountRupees)

        val positive = dto(estimatedCost = 5.0, contractedAmountRupees = 1500.0).toDomain()
        assertEquals(5.0, positive.estimatedCostRupees!!, 0.0)
        assertEquals(1500.0, positive.contractedAmountRupees!!, 0.0)
    }

    @Test fun `ratings outside 1 to 5 collapse to null`() {
        val tooLow = dto(hospitalRating = 0, engineerRating = -3).toDomain()
        assertNull(tooLow.hospitalRating)
        assertNull(tooLow.engineerRating)

        val tooHigh = dto(hospitalRating = 6, engineerRating = 99).toDomain()
        assertNull(tooHigh.hospitalRating)
        assertNull(tooHigh.engineerRating)

        val valid = dto(hospitalRating = 5, engineerRating = 1).toDomain()
        assertEquals(5, valid.hospitalRating)
        assertEquals(1, valid.engineerRating)
    }

    @Test fun `photo lists drop blank entries`() {
        val dto = dto(
            issuePhotos = listOf("https://x/a.jpg", "", "  ", "https://x/b.jpg"),
            beforePhotos = listOf("", "https://x/c.jpg"),
            afterPhotos = listOf("  "),
        )
        val domain = dto.toDomain()
        assertEquals(listOf("https://x/a.jpg", "https://x/b.jpg"), domain.issuePhotos)
        assertEquals(listOf("https://x/c.jpg"), domain.beforePhotos)
        assertTrue(domain.afterPhotos.isEmpty())
    }

    @Test fun `unknown equipment_type maps to Other`() {
        val domain = dto(equipmentType = "robotic_surgery_v2").toDomain()
        assertEquals(RepairEquipmentCategory.Other, domain.equipmentCategory)
    }

    @Test fun `valid ISO timestamps parse to Instants`() {
        val domain = dto(
            startedAt = "2026-05-04T10:00:00Z",
            completedAt = "2026-05-04T12:30:00Z",
            createdAt = "2026-05-04T09:00:00Z",
            updatedAt = "2026-05-04T12:31:00Z",
        ).toDomain()
        assertEquals(Instant.parse("2026-05-04T10:00:00Z"), domain.startedAtInstant)
        assertEquals(Instant.parse("2026-05-04T12:30:00Z"), domain.completedAtInstant)
        assertEquals(Instant.parse("2026-05-04T09:00:00Z"), domain.createdAtInstant)
        assertEquals(Instant.parse("2026-05-04T12:31:00Z"), domain.updatedAtInstant)
    }

    @Test fun `malformed timestamps degrade to null instead of throwing`() {
        val domain = dto(
            startedAt = "yesterday at noon",
            completedAt = "",
            createdAt = "2026-13-99",
        ).toDomain()
        assertNull(domain.startedAtInstant)
        assertNull(domain.completedAtInstant)
        assertNull(domain.createdAtInstant)
    }

    @Test fun `title prefers the first non-blank issue line trimmed to 80 chars`() {
        val long = "x".repeat(120)
        val domain = dto(
            issueDescription = "  \n   $long  \nmore detail",
        ).toDomain()
        assertEquals("x".repeat(80), domain.title)
    }

    @Test fun `title falls back to job number when issue is blank`() {
        val domain = dto(
            jobNumber = "RJ-001",
            issueDescription = "   \n   ",
            equipmentType = "imaging_radiology",
        ).toDomain()
        assertEquals("Job RJ-001", domain.title)
    }

    @Test fun `title falls back to category when issue and job number both blank`() {
        val domain = dto(
            jobNumber = null,
            issueDescription = "",
            equipmentType = "patient_monitoring",
        ).toDomain()
        assertEquals(RepairEquipmentCategory.PatientMonitoring.displayName, domain.title)
    }

    @Test fun `equipmentLabel uses brand model when present`() {
        val domain = dto(
            equipmentType = "imaging_radiology",
            equipmentBrand = "GE",
            equipmentModel = "Logiq P5",
        ).toDomain()
        assertEquals("GE Logiq P5", domain.equipmentLabel)
    }

    @Test fun `equipmentLabel falls back to category when brand model blank`() {
        val domain = dto(
            equipmentType = "patient_monitoring",
            equipmentBrand = "   ",
            equipmentModel = null,
        ).toDomain()
        assertEquals(RepairEquipmentCategory.PatientMonitoring.displayName, domain.equipmentLabel)
    }

    @Test fun `RepairBidDto maps to domain and trims blank note`() {
        val dto = RepairBidDto(
            id = "bid-1",
            repairJobId = "job-1",
            engineerUserId = "eng-1",
            amountRupees = 1500.0,
            etaHours = 24,
            note = "  ",
            status = "pending",
            createdAt = "2026-05-04T09:00:00Z",
            updatedAt = null,
        )
        val domain = dto.toDomain()
        assertEquals("bid-1", domain.id)
        assertEquals(1500.0, domain.amountRupees, 0.0)
        assertEquals(24, domain.etaHours)
        assertNull(domain.note)
        assertEquals(RepairBidStatus.Pending, domain.status)
        assertEquals(Instant.parse("2026-05-04T09:00:00Z"), domain.createdAtInstant)
        assertNull(domain.updatedAtInstant)
    }

    @Test fun `RepairBidDto malformed timestamp degrades to null`() {
        val dto = RepairBidDto(
            id = "bid-2",
            repairJobId = "job-1",
            engineerUserId = "eng-1",
            amountRupees = 1000.0,
            createdAt = "not-a-time",
        )
        assertNull(dto.toDomain().createdAtInstant)
    }

    private fun dto(
        id: String = "job-1",
        jobNumber: String? = "RJ-001",
        equipmentType: String? = "imaging_radiology",
        equipmentBrand: String? = null,
        equipmentModel: String? = null,
        urgency: String? = "scheduled",
        status: String? = "requested",
        issueDescription: String = "MRI gantry not aligning",
        estimatedCost: Double? = 1200.0,
        contractedAmountRupees: Double? = null,
        scheduledDate: String? = "2026-05-05",
        scheduledTimeSlot: String? = "10:00-11:00",
        siteLocation: String? = "Block A",
        hospitalUserId: String? = "hosp-1",
        engineerId: String? = null,
        startedAt: String? = null,
        completedAt: String? = null,
        createdAt: String? = null,
        updatedAt: String? = null,
        hospitalRating: Int? = null,
        engineerRating: Int? = null,
        hospitalReview: String? = null,
        engineerReview: String? = null,
        issuePhotos: List<String>? = null,
        beforePhotos: List<String>? = null,
        afterPhotos: List<String>? = null,
    ) = RepairJobDto(
        id = id,
        jobNumber = jobNumber,
        equipmentType = equipmentType,
        equipmentBrand = equipmentBrand,
        equipmentModel = equipmentModel,
        urgency = urgency,
        status = status,
        issueDescription = issueDescription,
        estimatedCost = estimatedCost,
        contractedAmountRupees = contractedAmountRupees,
        scheduledDate = scheduledDate,
        scheduledTimeSlot = scheduledTimeSlot,
        siteLocation = siteLocation,
        hospitalUserId = hospitalUserId,
        engineerId = engineerId,
        startedAt = startedAt,
        completedAt = completedAt,
        createdAt = createdAt,
        updatedAt = updatedAt,
        hospitalRating = hospitalRating,
        engineerRating = engineerRating,
        hospitalReview = hospitalReview,
        engineerReview = engineerReview,
        issuePhotos = issuePhotos,
        beforePhotos = beforePhotos,
        afterPhotos = afterPhotos,
    )
}
