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
 * Read-only NABH audit bundle for one asset (round 494):
 * nabh_bundle_for_equipment(p_hospital_user_id, p_equipment_serial, p_months
 * default 24) — the Digital Service Reports for that equipment over the window,
 * each with signatures (+ signer name/role), IEC 62353 / calibration pass
 * flags, readings and parts. Authorized server-side to the owning hospital
 * (auth.uid() = p_hospital_user_id) or a founder — caller passes their own uid.
 * The structured in-app preview behind the downloadable NABH export ZIP.
 */
@Singleton
class NabhBundleRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class NabhDsr(
        @SerialName("dsr_id") val dsrId: String,
        @SerialName("repair_job_id") val repairJobId: String? = null,
        @SerialName("equipment_brand") val equipmentBrand: String? = null,
        @SerialName("equipment_model") val equipmentModel: String? = null,
        @SerialName("equipment_type") val equipmentType: String? = null,
        @SerialName("engineer_signature_at") val engineerSignatureAt: String? = null,
        @SerialName("hospital_signature_at") val hospitalSignatureAt: String? = null,
        @SerialName("hospital_signer_name") val hospitalSignerName: String? = null,
        @SerialName("hospital_signer_role") val hospitalSignerRole: String? = null,
        @SerialName("iec_62353_passed") val iec62353Passed: Boolean? = null,
        @SerialName("calibration_within_oem") val calibrationWithinOem: Boolean? = null,
        @SerialName("pre_post_readings") val prePostReadings: JsonElement? = null,
        @SerialName("parts_replaced") val partsReplaced: JsonElement? = null,
        @SerialName("status") val status: String = "",
    )

    suspend fun fetch(hospitalUserId: String, equipmentSerial: String): Result<List<NabhDsr>> = runCatching {
        client.postgrest.rpc(
            function = "nabh_bundle_for_equipment",
            parameters = buildJsonObject {
                put("p_hospital_user_id", JsonPrimitive(hospitalUserId))
                put("p_equipment_serial", JsonPrimitive(equipmentSerial))
            },
        ).decodeList<NabhDsr>()
    }
}
