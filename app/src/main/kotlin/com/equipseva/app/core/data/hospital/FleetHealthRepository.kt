package com.equipseva.app.core.data.hospital

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * Read-only per-asset reliability rollup for the calling hospital via
 * hospital_fleet_health(p_days) (round 508) — auth.uid()-scoped server-side.
 * For each piece of equipment the hospital has logged repair jobs against it
 * returns MTBF / MTTR / uptime over the window, total downtime, whether the
 * asset is a replacement candidate, and the next PM due date. Concrete
 * @Singleton with constructor injection; no @Binds module needed.
 */
@Singleton
class FleetHealthRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class FleetAsset(
        @SerialName("equipment_type") val equipmentType: String? = null,
        @SerialName("equipment_brand") val equipmentBrand: String? = null,
        @SerialName("equipment_model") val equipmentModel: String? = null,
        @SerialName("equipment_serial") val equipmentSerial: String? = null,
        @SerialName("failure_count_window") val failureCountWindow: Int = 0,
        // NUMERIC columns that can be NULL when the window has too little data
        // to compute a mean (e.g. a single open failure → no MTTR yet).
        @SerialName("mtbf_days") val mtbfDays: Double? = null,
        @SerialName("mttr_hours") val mttrHours: Double? = null,
        @SerialName("total_downtime_hours") val totalDowntimeHours: Double = 0.0,
        @SerialName("uptime_pct") val uptimePct: Double = 100.0,
        @SerialName("replacement_candidate") val replacementCandidate: Boolean = false,
        @SerialName("last_failure_at") val lastFailureAt: String? = null,
        @SerialName("next_pm_due_at") val nextPmDueAt: String? = null,
    )

    /**
     * @param days trailing window for the reliability metrics. The RPC
     * defaults to 365; we pass it explicitly so the screen can offer other
     * windows later without a repo change.
     */
    suspend fun fetch(days: Int = 365): Result<List<FleetAsset>> = runCatching {
        client.postgrest.rpc(
            function = "hospital_fleet_health",
            parameters = buildJsonObject { put("p_days", JsonPrimitive(days)) },
        ).decodeList<FleetAsset>()
    }
}
