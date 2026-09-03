package com.equipseva.app.features.amc

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * Read-side repo for the hospital's Predictive PM (preventive
 * maintenance) calendar (round507, shipped 2026-06 as v0.4 Phase 4 #4).
 *
 * The backend has run standalone since round507 — a daily cron
 * (`recompute_all_pm_schedules_daily`, 04:00 IST) walks every
 * hospital's signed DSRs and forward-projects the next PM due date
 * per piece of equipment — but no client ever called it; the Android
 * app shipped no screen against it. This repo + [HospitalPmCalendarScreen]
 * (round3770) is the first caller.
 */
@Singleton
class HospitalPmCalendarRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class PmScheduleItem(
        val id: String,
        @SerialName("equipment_type") val equipmentType: String,
        @SerialName("equipment_brand") val equipmentBrand: String? = null,
        @SerialName("equipment_model") val equipmentModel: String? = null,
        @SerialName("equipment_serial") val equipmentSerial: String? = null,
        @SerialName("interval_days") val intervalDays: Int,
        @SerialName("last_service_at") val lastServiceAt: String? = null,
        @SerialName("next_pm_due_at") val nextPmDueAt: String,
        @SerialName("days_until_due") val daysUntilDue: Double,
        val status: String,
    )

    /**
     * Best-effort forward-recompute for just this hospital, called
     * before [fetchUpcoming] so a DSR signed minutes ago shows up
     * immediately instead of waiting for the next 04:00 IST cron tick.
     * `recompute_pm_schedule` is idempotent (ON CONFLICT DO UPDATE) so
     * calling it more than once a day is harmless — safe to run on
     * every cold-load + pull-to-refresh.
     */
    suspend fun recomputeSchedule(hospitalUserId: String): Result<Int> = runCatching {
        val raw = client.postgrest.rpc(
            function = "recompute_pm_schedule",
            parameters = buildJsonObject { put("p_hospital_user_id", JsonPrimitive(hospitalUserId)) },
        ).data
        raw.trim().trim('"').toIntOrNull() ?: 0
    }

    suspend fun fetchUpcoming(daysAhead: Int = 60): Result<List<PmScheduleItem>> = runCatching {
        client.postgrest.rpc(
            function = "hospital_upcoming_pm",
            parameters = buildJsonObject { put("p_days_ahead", JsonPrimitive(daysAhead)) },
        ).decodeList<PmScheduleItem>()
    }
}
