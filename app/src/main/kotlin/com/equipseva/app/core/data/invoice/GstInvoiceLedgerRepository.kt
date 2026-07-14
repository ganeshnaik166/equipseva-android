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
 * Read-only ledger of the current user's GST invoices via my_gst_invoices()
 * (r491) — auth.uid()-scoped server-side, returns BOTH directions:
 * "incoming" (a bill addressed to the user, e.g. a hospital's repair/AMC
 * invoice) and "outgoing" (one the user issued). Concrete @Singleton with
 * constructor injection; no @Binds module needed.
 */
@Singleton
class GstInvoiceLedgerRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class GstInvoiceRow(
        @SerialName("id") val id: String,
        @SerialName("invoice_serial") val invoiceSerial: String,
        @SerialName("direction") val direction: String, // "incoming" | "outgoing"
        @SerialName("counterparty_name") val counterpartyName: String? = null,
        @SerialName("source_kind") val sourceKind: String? = null,
        @SerialName("taxable_amount_rupees") val taxableAmountRupees: Double = 0.0,
        @SerialName("total_gst_rupees") val totalGstRupees: Double = 0.0,
        @SerialName("total_invoice_rupees") val totalInvoiceRupees: Double = 0.0,
        @SerialName("rcm_applicable") val rcmApplicable: Boolean = false,
        @SerialName("status") val status: String,
        @SerialName("issued_at") val issuedAt: String,
    )

    suspend fun fetchMyInvoices(limit: Int = 100): Result<List<GstInvoiceRow>> = runCatching {
        client.postgrest.rpc(
            function = "my_gst_invoices",
            parameters = buildJsonObject { put("p_limit", JsonPrimitive(limit)) },
        ).decodeList<GstInvoiceRow>()
    }
}
