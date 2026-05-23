package com.equipseva.app.core.data.repair

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins [NearbyRepairJobDto] → [RepairJobWithDistance] mapping. The
 * `list_nearby_repair_jobs` RPC denormalises the org coords into the
 * job row and computes the haversine `distance_km`. The mapper forwards
 * those onto the wrapper while delegating the rest of the job-row
 * shape to the regular [RepairJobDto.toDomain]. A regression that
 * dropped distance / coords would break the nearby feed's "12 km away"
 * label + the map-marker layout.
 */
class NearbyRepairJobDtoMapperTest {

    private fun emptyDto(id: String = "j1") = NearbyRepairJobDto(id = id)

    @Test fun `minimal dto delegates job-side defaults to RepairJobDto mapper`() {
        val out = emptyDto().toDomainWithDistance()
        assertEquals("j1", out.job.id)
        // Distance default is 0.0 per the dto's defaulted column.
        assertEquals(0.0, out.distanceKm, 0.0)
        assertNull(out.hospitalLatitude)
        assertNull(out.hospitalLongitude)
        // Title fallback chain — Other category, no jobNumber.
        assertEquals("Other", out.job.title)
    }

    @Test fun `distance and coords forward to the wrapper`() {
        val out = emptyDto().copy(
            hospitalLatitude = 12.97,
            hospitalLongitude = 77.59,
            distanceKm = 4.2,
        ).toDomainWithDistance()
        assertEquals(12.97, out.hospitalLatitude!!, 0.001)
        assertEquals(77.59, out.hospitalLongitude!!, 0.001)
        assertEquals(4.2, out.distanceKm, 0.001)
    }

    @Test fun `mapper composes job fields through the inner RepairJobDto path`() {
        val out = emptyDto().copy(
            jobNumber = "RJ-002",
            equipmentType = "imaging_radiology",
            equipmentBrand = "GE",
            equipmentModel = "Logiq P5",
            urgency = "emergency",
            status = "requested",
            issueDescription = "Beam alignment drift",
            estimatedCost = 6500.0,
            scheduledDate = "2026-05-22",
            scheduledTimeSlot = "morning",
            distanceKm = 1.0,
            createdAt = "2026-05-21T08:00:00Z",
        ).toDomainWithDistance()

        // Title is first issue line — pins the delegation to the
        // inner mapper's title-resolution chain.
        assertEquals("Beam alignment drift", out.job.title)
        assertEquals("RJ-002", out.job.jobNumber)
        assertEquals(RepairEquipmentCategory.ImagingRadiology, out.job.equipmentCategory)
        assertEquals("GE", out.job.equipmentBrand)
        assertEquals("Logiq P5", out.job.equipmentModel)
        assertEquals(RepairJobUrgency.Emergency, out.job.urgency)
        assertEquals(RepairJobStatus.Requested, out.job.status)
        assertEquals("Beam alignment drift", out.job.issueDescription)
        assertEquals(6500.0, out.job.estimatedCostRupees!!, 0.001)
        assertEquals("2026-05-22", out.job.scheduledDate)
        assertEquals("morning", out.job.scheduledTimeSlot)
        // Nearby RPC narrows the column set — siteLocation / lat / lng
        // / engineerId / etc are NOT projected. The mapper must
        // produce sensible defaults for those.
        assertNull(out.job.siteLocation)
        assertNull(out.job.engineerId)
    }
}
