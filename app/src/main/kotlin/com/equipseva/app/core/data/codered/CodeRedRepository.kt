package com.equipseva.app.core.data.codered

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * Engineer Code Red emergency response (round 509). An engineer reads the
 * still-open emergencies they were paged for — from code_red_dispatch_events
 * (RLS-scoped to engineer_user_id = auth.uid()) with the parent request
 * embedded — and accepts (first wins) or declines each. accept_code_red /
 * decline_code_red are SECURITY DEFINER and re-check the paged state, so a
 * stale card can't over-accept.
 */
@Singleton
class CodeRedRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    /** A single actionable emergency, flattened from the paged dispatch event
     *  plus its embedded request. */
    data class CodeRed(
        val id: String,
        val equipmentType: String,
        val equipmentBrand: String?,
        val equipmentModel: String?,
        val equipmentSerial: String?,
        val description: String,
        val feeCeilingRupees: Double,
        val status: String,
        val slaDeadlineAt: String?,
        val distanceKmAtPage: Double?,
    )

    @Serializable
    private data class DispatchRow(
        @SerialName("code_red_id") val codeRedId: String = "",
        @SerialName("outcome") val outcome: String = "",
        @SerialName("distance_km_at_page") val distanceKmAtPage: Double? = null,
        @SerialName("code_red_requests") val request: RequestRow? = null,
    )

    @Serializable
    private data class RequestRow(
        @SerialName("id") val id: String = "",
        @SerialName("equipment_type") val equipmentType: String = "",
        @SerialName("equipment_brand") val equipmentBrand: String? = null,
        @SerialName("equipment_model") val equipmentModel: String? = null,
        @SerialName("equipment_serial") val equipmentSerial: String? = null,
        @SerialName("description") val description: String = "",
        @SerialName("emergency_fee_ceiling_rupees") val feeCeilingRupees: Double = 0.0,
        @SerialName("status") val status: String = "",
        @SerialName("sla_deadline_at") val slaDeadlineAt: String? = null,
    )

    private companion object {
        const val EMBED = "code_red_id, outcome, distance_km_at_page, " +
            "code_red_requests(id, equipment_type, equipment_brand, equipment_model, " +
            "equipment_serial, description, emergency_fee_ceiling_rupees, status, sla_deadline_at)"
    }

    /**
     * The emergencies this engineer can still act on: their paged dispatch
     * events whose request is still open. Sorted by SLA deadline (soonest
     * first) so the most urgent is on top.
     */
    suspend fun openForMe(engineerUserId: String): Result<List<CodeRed>> = runCatching {
        client.postgrest.from("code_red_dispatch_events")
            .select(columns = Columns.raw(EMBED)) {
                filter {
                    eq("engineer_user_id", engineerUserId)
                    eq("outcome", "paged")
                }
            }
            .decodeList<DispatchRow>()
            .mapNotNull { d ->
                val r = d.request ?: return@mapNotNull null
                if (r.status != "open") return@mapNotNull null
                CodeRed(
                    id = r.id,
                    equipmentType = r.equipmentType,
                    equipmentBrand = r.equipmentBrand,
                    equipmentModel = r.equipmentModel,
                    equipmentSerial = r.equipmentSerial,
                    description = r.description,
                    feeCeilingRupees = r.feeCeilingRupees,
                    status = r.status,
                    slaDeadlineAt = r.slaDeadlineAt,
                    distanceKmAtPage = d.distanceKmAtPage,
                )
            }
            .sortedBy { it.slaDeadlineAt ?: "￿" }
    }

    suspend fun accept(codeRedId: String): Result<Unit> = runCatching {
        client.postgrest.rpc(
            function = "accept_code_red",
            parameters = buildJsonObject { put("p_code_red_id", JsonPrimitive(codeRedId)) },
        )
        Unit
    }

    suspend fun decline(codeRedId: String, reason: String?): Result<Unit> = runCatching {
        client.postgrest.rpc(
            function = "decline_code_red",
            parameters = buildJsonObject {
                put("p_code_red_id", JsonPrimitive(codeRedId))
                put(
                    "p_reason",
                    reason?.trim()?.takeIf { it.isNotEmpty() }?.let { JsonPrimitive(it) } ?: JsonNull,
                )
            },
        )
        Unit
    }
}
