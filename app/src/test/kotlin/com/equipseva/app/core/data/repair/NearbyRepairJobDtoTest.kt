package com.equipseva.app.core.data.repair

import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * `list_nearby_repair_jobs` is a SECURITY DEFINER RPC that pre-joins the
 * hospital org + computes haversine distance, returning a narrowed column
 * set. The Android mapper reuses RepairJobDto.toDomain under the hood, so
 * verify it forwards the keys correctly and carries the distance + lat/lng
 * pair across to RepairJobWithDistance.
 */
class NearbyRepairJobDtoTest {

    private val json = Json { ignoreUnknownKeys = true }

    @Test fun `RPC row maps to RepairJobWithDistance with distance and coords`() {
        val dto = json.decodeFromString(
            NearbyRepairJobDto.serializer(),
            """
            {
              "id": "job-1",
              "job_number": "RJ-101",
              "hospital_user_id": "hosp-1",
              "hospital_org_id": "org-1",
              "equipment_type": "imaging_radiology",
              "equipment_brand": "GE",
              "equipment_model": "Logiq P5",
              "urgency": "same_day",
              "status": "requested",
              "issue_description": "Probe interference",
              "scheduled_date": "2026-05-05",
              "scheduled_time_slot": "10:00-11:00",
              "estimated_cost": 1500.0,
              "hospital_latitude": 12.9716,
              "hospital_longitude": 77.5946,
              "distance_km": 7.4,
              "created_at": "2026-05-04T09:00:00Z"
            }
            """.trimIndent(),
        )

        val result = dto.toDomainWithDistance()
        assertEquals(7.4, result.distanceKm, 0.0001)
        assertEquals(12.9716, result.hospitalLatitude!!, 0.0001)
        assertEquals(77.5946, result.hospitalLongitude!!, 0.0001)

        val job = result.job
        assertEquals("job-1", job.id)
        assertEquals("RJ-101", job.jobNumber)
        assertEquals(RepairEquipmentCategory.ImagingRadiology, job.equipmentCategory)
        assertEquals("GE", job.equipmentBrand)
        assertEquals("Logiq P5", job.equipmentModel)
        assertEquals(RepairJobStatus.Requested, job.status)
        assertEquals(RepairJobUrgency.SameDay, job.urgency)
        // The first non-blank issue line is the title (under 80 chars).
        assertEquals("Probe interference", job.title)
        assertEquals(1500.0, job.estimatedCostRupees!!, 0.0)
    }

    @Test fun `missing hospital coords stay null on the projection`() {
        val dto = json.decodeFromString(
            NearbyRepairJobDto.serializer(),
            """
            {
              "id": "job-2",
              "issue_description": "ECG patches running out",
              "distance_km": 0.0
            }
            """.trimIndent(),
        )

        val result = dto.toDomainWithDistance()
        assertNull(result.hospitalLatitude)
        assertNull(result.hospitalLongitude)
        assertEquals(0.0, result.distanceKm, 0.0)
        // No equipment_type ⇒ falls back to Other on the domain side.
        assertEquals(RepairEquipmentCategory.Other, result.job.equipmentCategory)
    }
}
