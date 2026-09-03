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
 * Round 3771 — hospital-facing Equipment Fleet Health backend
 * (round508, v0.4 Phase 4 "Equipment Fleet Console + MTBF/MTTR
 * Dashboard"). Same discovery as [HospitalPmCalendarRepository]
 * (round3770): the backend has existed since round508 with zero
 * Kotlin caller — only `founder_fleet_red_flags` (a separate,
 * founder-only cockpit query in the same migration) was ever wired,
 * into the web console. This repo is the first client of
 * `hospital_fleet_health` / `asset_history`.
 */
@Singleton
class HospitalFleetHealthRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class FleetHealthItem(
        @SerialName("equipment_type") val equipmentType: String,
        @SerialName("equipment_brand") val equipmentBrand: String? = null,
        @SerialName("equipment_model") val equipmentModel: String? = null,
        @SerialName("equipment_serial") val equipmentSerial: String? = null,
        @SerialName("failure_count_window") val failureCountWindow: Int,
        @SerialName("mtbf_days") val mtbfDays: Double? = null,
        @SerialName("mttr_hours") val mttrHours: Double? = null,
        @SerialName("total_downtime_hours") val totalDowntimeHours: Double,
        @SerialName("uptime_pct") val uptimePct: Double,
        @SerialName("replacement_candidate") val replacementCandidate: Boolean,
        @SerialName("last_failure_at") val lastFailureAt: String? = null,
        @SerialName("next_pm_due_at") val nextPmDueAt: String? = null,
    )

    @Serializable
    data class AssetHistoryEvent(
        @SerialName("event_kind") val eventKind: String,
        @SerialName("event_at") val eventAt: String? = null,
        @SerialName("reference_id") val referenceId: String? = null,
        val summary: String,
    )

    suspend fun fetchFleetHealth(daysAhead: Int = 365): Result<List<FleetHealthItem>> = runCatching {
        client.postgrest.rpc(
            function = "hospital_fleet_health",
            parameters = buildJsonObject { put("p_days", JsonPrimitive(daysAhead)) },
        ).decodeList<FleetHealthItem>()
    }

    suspend fun fetchAssetHistory(
        hospitalUserId: String,
        equipmentSerial: String,
    ): Result<List<AssetHistoryEvent>> = runCatching {
        client.postgrest.rpc(
            function = "asset_history",
            parameters = buildJsonObject {
                put("p_hospital_user_id", JsonPrimitive(hospitalUserId))
                put("p_equipment_serial", JsonPrimitive(equipmentSerial))
            },
        ).decodeList<AssetHistoryEvent>()
    }
}
