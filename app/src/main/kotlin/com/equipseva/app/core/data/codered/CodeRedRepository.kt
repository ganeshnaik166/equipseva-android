package com.equipseva.app.core.data.codered

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
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
        val warroomUrl: String? = null,
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
        @SerialName("warroom_url") val warroomUrl: String? = null,
    )

    private fun RequestRow.toCodeRed(distanceKmAtPage: Double?) = CodeRed(
        id = id,
        equipmentType = equipmentType,
        equipmentBrand = equipmentBrand,
        equipmentModel = equipmentModel,
        equipmentSerial = equipmentSerial,
        description = description,
        feeCeilingRupees = feeCeilingRupees,
        status = status,
        slaDeadlineAt = slaDeadlineAt,
        distanceKmAtPage = distanceKmAtPage,
        warroomUrl = warroomUrl,
    )

    private companion object {
        private const val REQUEST_COLS = "id, equipment_type, equipment_brand, equipment_model, " +
            "equipment_serial, description, emergency_fee_ceiling_rupees, status, sla_deadline_at, warroom_url"
        const val EMBED = "code_red_id, outcome, distance_km_at_page, code_red_requests($REQUEST_COLS)"
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
                r.toCodeRed(d.distanceKmAtPage)
            }
            .sortedBy { it.slaDeadlineAt ?: "￿" }
    }

    /**
     * The emergency this engineer has accepted and is now attending (r1438):
     * their code_red_requests still in 'engineer_accepted' (RLS lets the
     * accepted engineer read the row). Keeps the committed emergency — and its
     * war-room link — visible after it leaves the actionable [openForMe] feed.
     */
    suspend fun acceptedByMe(engineerUserId: String): Result<List<CodeRed>> = runCatching {
        client.postgrest.from("code_red_requests")
            .select(columns = Columns.raw(REQUEST_COLS)) {
                filter {
                    eq("accepted_engineer_user_id", engineerUserId)
                    eq("status", "engineer_accepted")
                }
                order("accepted_at", Order.DESCENDING)
            }
            .decodeList<RequestRow>()
            .map { it.toCodeRed(distanceKmAtPage = null) }
    }

    // -----------------------------------------------------------------
    //  r1426 — hospital side: fire + track own Code Reds
    // -----------------------------------------------------------------

    /** A Code Red the hospital itself raised. */
    @Serializable
    data class HospitalCodeRed(
        @SerialName("id") val id: String,
        @SerialName("equipment_type") val equipmentType: String = "",
        @SerialName("equipment_brand") val equipmentBrand: String? = null,
        @SerialName("equipment_model") val equipmentModel: String? = null,
        @SerialName("equipment_serial") val equipmentSerial: String? = null,
        @SerialName("description") val description: String = "",
        @SerialName("emergency_fee_ceiling_rupees") val feeCeilingRupees: Double = 0.0,
        @SerialName("status") val status: String = "",
        @SerialName("sla_minutes") val slaMinutes: Int = 60,
        @SerialName("sla_deadline_at") val slaDeadlineAt: String? = null,
        @SerialName("accepted_at") val acceptedAt: String? = null,
        @SerialName("created_at") val createdAt: String? = null,
        // War-room coordination link (WhatsApp/Slack), set founder-side; null
        // when none was attached to this emergency.
        @SerialName("warroom_url") val warroomUrl: String? = null,
    )

    @Serializable
    private data class TaxonomyRow(@SerialName("equipment_type") val equipmentType: String = "")

    /** Equipment types eligible for a Code Red — the v0.4-allowed taxonomy
     *  classes, read live (the table is world-readable to authenticated) so the
     *  list never drifts from the server's hard-gate. */
    suspend fun allowedEquipmentTypes(): Result<List<String>> = runCatching {
        client.postgrest.from("equipment_taxonomy_class")
            .select(columns = Columns.list("equipment_type")) {
                filter { eq("allowed_in_v04", true) }
                order("equipment_type", Order.ASCENDING)
            }
            .decodeList<TaxonomyRow>()
            .map { it.equipmentType }
    }

    /** The hospital's own Code Reds, newest first (RLS scopes to the caller). */
    suspend fun myRequests(hospitalUserId: String): Result<List<HospitalCodeRed>> = runCatching {
        client.postgrest.from("code_red_requests").select {
            filter { eq("hospital_user_id", hospitalUserId) }
            order("created_at", Order.DESCENDING)
        }.decodeList<HospitalCodeRed>()
    }

    /** Fire a Code Red. equipmentType must be an allowed taxonomy class or the
     *  server rejects it; description is 10-2000 chars, fee ceiling 0-50000,
     *  SLA 15-1440 min — all validated server-side too. */
    suspend fun open(
        equipmentType: String,
        brand: String?,
        model: String?,
        serial: String?,
        description: String,
        feeCeilingRupees: Double,
        slaMinutes: Int,
    ): Result<Unit> = runCatching {
        client.postgrest.rpc(
            function = "open_code_red_request",
            parameters = buildJsonObject {
                put("p_equipment_type", JsonPrimitive(equipmentType))
                put("p_equipment_brand", brand.orNull())
                put("p_equipment_model", model.orNull())
                put("p_equipment_serial", serial.orNull())
                put("p_description", JsonPrimitive(description.trim()))
                put("p_emergency_fee_ceiling_rupees", JsonPrimitive(feeCeilingRupees))
                put("p_sla_minutes", JsonPrimitive(slaMinutes))
            },
        )
        Unit
    }

    private fun String?.orNull() =
        this?.trim()?.takeIf { it.isNotEmpty() }?.let { JsonPrimitive(it) } ?: JsonNull

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
