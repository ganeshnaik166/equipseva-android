package com.equipseva.app.core.data.hospital

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * Read-only chronological timeline for one asset (identified by serial) via
 * asset_history(p_hospital_user_id, p_equipment_serial) (round 508). Unions
 * repair jobs, service reports (DSRs) and PM-schedule events for the asset,
 * newest first. Authorized server-side only for the owning hospital
 * (auth.uid() = p_hospital_user_id) or a founder — the caller passes their
 * own uid. The drill-down behind a Fleet Health row.
 */
@Singleton
class AssetHistoryRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class AssetEvent(
        // repair_job | dsr_report | pm_scheduled
        @SerialName("event_kind") val eventKind: String = "",
        @SerialName("event_at") val eventAt: String? = null,
        @SerialName("reference_id") val referenceId: String? = null,
        @SerialName("summary") val summary: String? = null,
        // Extra per-event payload; kept for forward-compat, not rendered.
        @SerialName("details") val details: JsonElement? = null,
    )

    suspend fun fetch(hospitalUserId: String, equipmentSerial: String): Result<List<AssetEvent>> = runCatching {
        client.postgrest.rpc(
            function = "asset_history",
            parameters = buildJsonObject {
                put("p_hospital_user_id", JsonPrimitive(hospitalUserId))
                put("p_equipment_serial", JsonPrimitive(equipmentSerial))
            },
        ).decodeList<AssetEvent>()
    }
}
