package com.equipseva.app.core.data.repair

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * The booking form → insert payload conversion looks innocent (a giant
 * copy-block) but the blank → null collapse is load-bearing: if a blank
 * string lands on `urgency` or `equipment_brand`, the column's CHECK
 * constraint / default fails or the row stores literal "" which then
 * fails the .takeIf { it.isNotBlank() } guard on the read side. Pin
 * every collapse + every passthrough.
 */
class RepairJobDraftInsertTest {

    private fun draft(
        hospitalUserId: String = "hosp-1",
        hospitalOrgId: String? = null,
        issueDescription: String = "MRI gantry stuck",
        equipmentCategory: RepairEquipmentCategory = RepairEquipmentCategory.ImagingRadiology,
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
        hospitalUserId = hospitalUserId,
        hospitalOrgId = hospitalOrgId,
        issueDescription = issueDescription,
        equipmentCategory = equipmentCategory,
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

    @Test fun `equipmentCategory falls through to its storage key`() {
        val dto = draft(equipmentCategory = RepairEquipmentCategory.Dental).toInsertDto()
        assertEquals("dental", dto.equipmentType)
    }

    @Test fun `urgency falls through to its storage key`() {
        val dto = draft(urgency = RepairJobUrgency.Emergency).toInsertDto()
        assertEquals("emergency", dto.urgency)
    }

    @Test fun `Unknown urgency collapses to null so the server default fires`() {
        // RepairJobUrgency.Unknown.storageKey is "" — the form should
        // never persist a blank to bypass the urgency CHECK constraint.
        val dto = draft(urgency = RepairJobUrgency.Unknown).toInsertDto()
        assertNull(dto.urgency)
    }

    @Test fun `blank optional strings collapse to null`() {
        val dto = draft(
            hospitalOrgId = "   ",
            equipmentBrand = "",
            equipmentModel = "  ",
            equipmentSerial = " ",
            siteLocation = "",
            scheduledDate = "  ",
            scheduledTimeSlot = "",
        ).toInsertDto()

        assertNull(dto.hospitalOrgId)
        assertNull(dto.equipmentBrand)
        assertNull(dto.equipmentModel)
        assertNull(dto.equipmentSerial)
        assertNull(dto.siteLocation)
        assertNull(dto.scheduledDate)
        assertNull(dto.scheduledTimeSlot)
    }

    @Test fun `empty photo list collapses to null instead of an empty array`() {
        // Postgrest treats `[]` and `null` differently for the issue_photos
        // column — Postgres would write a literal empty array vs a NULL.
        // Keep them both representable: empty list means "no photos
        // attached", which is null on the wire.
        val dto = draft(issuePhotos = emptyList()).toInsertDto()
        assertNull(dto.issuePhotos)
    }

    @Test fun `non-empty photo list passes through`() {
        val dto = draft(issuePhotos = listOf("a.jpg", "b.jpg")).toInsertDto()
        assertEquals(listOf("a.jpg", "b.jpg"), dto.issuePhotos)
    }

    @Test fun `zero or negative estimated cost collapses to null`() {
        val zero = draft(estimatedCostRupees = 0.0).toInsertDto()
        assertNull(zero.estimatedCost)

        val negative = draft(estimatedCostRupees = -100.0).toInsertDto()
        assertNull(negative.estimatedCost)

        val positive = draft(estimatedCostRupees = 1500.0).toInsertDto()
        assertEquals(1500.0, positive.estimatedCost!!, 0.0)
    }

    @Test fun `latitude and longitude pass through even at zero`() {
        // Lat/lng of 0 is a valid coordinate (Gulf of Guinea); the booking
        // form never realistically writes it, but we must not silently
        // null it out.
        val dto = draft(siteLatitude = 0.0, siteLongitude = 0.0).toInsertDto()
        assertEquals(0.0, dto.siteLatitude!!, 0.0)
        assertEquals(0.0, dto.siteLongitude!!, 0.0)
    }

    @Test fun `required fields are forwarded verbatim`() {
        val dto = draft(
            hospitalUserId = "hosp-9",
            issueDescription = "ECG patches running out",
        ).toInsertDto()
        assertEquals("hosp-9", dto.hospitalUserId)
        assertEquals("ECG patches running out", dto.issueDescription)
    }
}
