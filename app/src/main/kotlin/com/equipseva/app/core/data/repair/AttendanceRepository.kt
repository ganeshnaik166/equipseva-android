package com.equipseva.app.core.data.repair

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * Read-only GPS attendance timeline for one repair job (round 496):
 * attendance_for_job(p_repair_job_id) — arrival check-in / departure
 * check-out events with the engineer's captured lat/lng, accuracy, distance
 * from the hospital, and a suspicious-distance flag. Authorized server-side
 * to the assigned engineer, the job's hospital, or a founder.
 */
@Singleton
class AttendanceRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class Attendance(
        @SerialName("id") val id: String,
        // arrival_checkin | departure_checkout
        @SerialName("event_kind") val eventKind: String = "",
        @SerialName("device_captured_at") val deviceCapturedAt: String? = null,
        @SerialName("engineer_lat") val engineerLat: Double? = null,
        @SerialName("engineer_lng") val engineerLng: Double? = null,
        @SerialName("engineer_accuracy_m") val engineerAccuracyM: Double? = null,
        @SerialName("distance_from_hospital_m") val distanceFromHospitalM: Double? = null,
        @SerialName("suspicious_distance") val suspiciousDistance: Boolean = false,
        @SerialName("created_at") val createdAt: String? = null,
    )

    suspend fun fetch(repairJobId: String): Result<List<Attendance>> = runCatching {
        client.postgrest.rpc(
            function = "attendance_for_job",
            parameters = buildJsonObject {
                put("p_repair_job_id", JsonPrimitive(repairJobId))
            },
        ).decodeList<Attendance>()
    }
}
