package com.equipseva.app.core.data.repair

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins the RepairJobInsertDto composition from a RepairJobDraft.
 * Every nullable string field folds blank → null so the wire DTO
 * doesn't carry empty strings into NOT NULL DEFAULT columns;
 * collections fold empty → null for the same reason; estimated cost
 * ≤ 0 folds to null so the UI's "0" skip-value doesn't surface as a
 * phantom "₹0 estimate" on every engineer's bid card.
 */
class BuildRepairJobInsertTest {

    private fun draft(
        hospitalOrgId: String? = null,
        equipmentBrand: String? = null,
        equipmentModel: String? = null,
        equipmentSerial: String? = null,
        siteLocation: String? = null,
        siteLatitude: Double? = null,
        siteLongitude: Double? = null,
        issuePhotos: List<String> = emptyList(),
        urgency: RepairJobUrgency = RepairJobUrgency.Scheduled,
        scheduledDate: String? = null,
        scheduledTimeSlot: String? = null,
        estimatedCostRupees: Double? = null,
    ) = RepairJobDraft(
        hospitalUserId = "u-1",
        hospitalOrgId = hospitalOrgId,
        issueDescription = "ultrasound probe arcing",
        equipmentCategory = RepairEquipmentCategory.ImagingRadiology,
        equipmentBrand = equipmentBrand,
        equipmentModel = equipmentModel,
        equipmentSerial = equipmentSerial,
        siteLocation = siteLocation,
        siteLatitude = siteLatitude,
        siteLongitude = siteLongitude,
        issuePhotos = issuePhotos,
        urgency = urgency,
        scheduledDate = scheduledDate,
        scheduledTimeSlot = scheduledTimeSlot,
        estimatedCostRupees = estimatedCostRupees,
    )

    @Test fun `minimal draft maps to lean DTO with everything optional folded to null`() {
        val dto = buildRepairJobInsert(draft())
        assertEquals("u-1", dto.hospitalUserId)
        assertNull(dto.hospitalOrgId)
        assertEquals("imaging_radiology", dto.equipmentType)
        assertNull(dto.equipmentBrand)
        assertNull(dto.equipmentModel)
        assertNull(dto.equipmentSerial)
        assertNull(dto.siteLocation)
        assertNull(dto.siteLatitude)
        assertNull(dto.siteLongitude)
        assertEquals("scheduled", dto.urgency)
        assertEquals("ultrasound probe arcing", dto.issueDescription)
        assertNull(dto.issuePhotos)
        assertNull(dto.scheduledDate)
        assertNull(dto.scheduledTimeSlot)
        assertNull(dto.estimatedCost)
    }

    @Test fun `blank string fields fold to null`() {
        val dto = buildRepairJobInsert(
            draft(
                hospitalOrgId = "  ",
                equipmentBrand = "",
                equipmentModel = "  ",
                equipmentSerial = "",
                siteLocation = "   ",
                scheduledDate = "",
                scheduledTimeSlot = "  ",
            ),
        )
        assertNull(dto.hospitalOrgId)
        assertNull(dto.equipmentBrand)
        assertNull(dto.equipmentModel)
        assertNull(dto.equipmentSerial)
        assertNull(dto.siteLocation)
        assertNull(dto.scheduledDate)
        assertNull(dto.scheduledTimeSlot)
    }

    @Test fun `non-blank string fields pass through`() {
        val dto = buildRepairJobInsert(
            draft(
                hospitalOrgId = "org-1",
                equipmentBrand = "GE",
                equipmentModel = "Logiq P5",
                equipmentSerial = "SN-12345",
                siteLocation = "Ward 3, Apollo Bengaluru",
                scheduledDate = "2026-05-22",
                scheduledTimeSlot = "morning",
            ),
        )
        assertEquals("org-1", dto.hospitalOrgId)
        assertEquals("GE", dto.equipmentBrand)
        assertEquals("Logiq P5", dto.equipmentModel)
        assertEquals("SN-12345", dto.equipmentSerial)
        assertEquals("Ward 3, Apollo Bengaluru", dto.siteLocation)
        assertEquals("2026-05-22", dto.scheduledDate)
        assertEquals("morning", dto.scheduledTimeSlot)
    }

    @Test fun `empty issuePhotos list folds to null`() {
        val dto = buildRepairJobInsert(draft(issuePhotos = emptyList()))
        assertNull(dto.issuePhotos)
    }

    @Test fun `non-empty issuePhotos list passes through`() {
        val urls = listOf("https://cdn/x1.jpg", "https://cdn/x2.jpg")
        val dto = buildRepairJobInsert(draft(issuePhotos = urls))
        assertEquals(urls, dto.issuePhotos)
    }

    @Test fun `zero estimated cost folds to null`() {
        // "0" is the UI's skip-value; pin so writing it as a phantom
        // ₹0 estimate doesn't slip past review.
        val dto = buildRepairJobInsert(draft(estimatedCostRupees = 0.0))
        assertNull(dto.estimatedCost)
    }

    @Test fun `negative estimated cost folds to null`() {
        val dto = buildRepairJobInsert(draft(estimatedCostRupees = -100.0))
        assertNull(dto.estimatedCost)
    }

    @Test fun `positive estimated cost passes through`() {
        val dto = buildRepairJobInsert(draft(estimatedCostRupees = 2500.0))
        assertEquals(2500.0, dto.estimatedCost!!, 0.001)
    }

    @Test fun `urgency uses the enum storageKey`() {
        // Pin so the wire DTO carries the lowercase server-side enum
        // value, not the Kotlin name.
        val emergency = buildRepairJobInsert(draft(urgency = RepairJobUrgency.Emergency))
        assertEquals("emergency", emergency.urgency)

        val sameDay = buildRepairJobInsert(draft(urgency = RepairJobUrgency.SameDay))
        assertEquals("same_day", sameDay.urgency)
    }

    @Test fun `Unknown urgency (storage_key empty) folds to null`() {
        // RepairJobUrgency.Unknown has storage_key "" — pin so the
        // takeIf-isNotBlank gate folds it to null rather than writing
        // an empty string into the urgency column.
        val dto = buildRepairJobInsert(draft(urgency = RepairJobUrgency.Unknown))
        assertNull(dto.urgency)
    }

    @Test fun `equipment category storage_key always passes through (no null fold)`() {
        // Equipment category is a required-on-the-form value; the
        // RepairEquipmentCategory.Other fallback still carries a
        // non-empty storageKey "other" so this is always present.
        val dto = buildRepairJobInsert(draft())
        assertEquals("imaging_radiology", dto.equipmentType)
    }

    @Test fun `lat lng pass through as-is (no null fold)`() {
        val dto = buildRepairJobInsert(
            draft(siteLatitude = 12.97, siteLongitude = 77.59),
        )
        assertEquals(12.97, dto.siteLatitude!!, 0.001)
        assertEquals(77.59, dto.siteLongitude!!, 0.001)
    }
}
