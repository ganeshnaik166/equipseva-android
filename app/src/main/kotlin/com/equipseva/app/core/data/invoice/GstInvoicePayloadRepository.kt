package com.equipseva.app.core.data.invoice

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * Read-only STRUCTURED GST tax-invoice payload for a completed repair job
 * (round 449/457/459): get_repair_invoice_payload(p_job_id) — invoice number
 * (FY-scoped), buyer (hospital) block with GSTIN + address, equipment line
 * item, and the CGST/SGST/IGST split at 18%. Party-scoped server-side
 * (hospital owner / job engineer / founder); returns 0 rows unless the job is
 * completed. Complements the existing generate_repair_invoice PDF flow
 * ([RepairInvoiceRepository]) with an in-app view.
 */
@Singleton
class GstInvoicePayloadRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class InvoicePayload(
        @SerialName("invoice_number") val invoiceNumber: String = "",
        @SerialName("invoice_date") val invoiceDate: String? = null,
        @SerialName("job_number") val jobNumber: String? = null,
        @SerialName("completed_at") val completedAt: String? = null,
        @SerialName("hospital_user_id") val hospitalUserId: String? = null,
        @SerialName("hospital_name") val hospitalName: String? = null,
        @SerialName("hospital_email") val hospitalEmail: String? = null,
        @SerialName("hospital_phone") val hospitalPhone: String? = null,
        @SerialName("hospital_gstin") val hospitalGstin: String? = null,
        @SerialName("hospital_address") val hospitalAddress: String? = null,
        @SerialName("hospital_city") val hospitalCity: String? = null,
        @SerialName("hospital_state") val hospitalState: String? = null,
        @SerialName("hospital_pincode") val hospitalPincode: String? = null,
        @SerialName("equipment_type") val equipmentType: String? = null,
        @SerialName("equipment_brand") val equipmentBrand: String? = null,
        @SerialName("equipment_model") val equipmentModel: String? = null,
        @SerialName("equipment_serial") val equipmentSerial: String? = null,
        @SerialName("issue_description") val issueDescription: String? = null,
        @SerialName("work_done") val workDone: String? = null,
        @SerialName("gross_rupees") val grossRupees: Double = 0.0,
        @SerialName("taxable_value") val taxableValue: Double = 0.0,
        @SerialName("gst_total") val gstTotal: Double = 0.0,
        @SerialName("cgst") val cgst: Double = 0.0,
        @SerialName("sgst") val sgst: Double = 0.0,
        @SerialName("igst") val igst: Double = 0.0,
        @SerialName("hsn_sac_code") val hsnSacCode: String? = null,
        @SerialName("service_description") val serviceDescription: String? = null,
    )

    suspend fun fetch(jobId: String): Result<InvoicePayload?> = runCatching {
        client.postgrest.rpc(
            function = "get_repair_invoice_payload",
            parameters = buildJsonObject { put("p_job_id", JsonPrimitive(jobId)) },
        ).decodeList<InvoicePayload>().firstOrNull()
    }
}
