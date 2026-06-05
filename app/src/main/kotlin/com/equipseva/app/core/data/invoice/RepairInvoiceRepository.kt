package com.equipseva.app.core.data.invoice

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.exceptions.RestException
import io.github.jan.supabase.functions.functions
import io.ktor.client.statement.bodyAsText
import io.ktor.http.isSuccess
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

// Round 449 — wraps generate_repair_invoice edge fn. The fn renders an
// HTML GST tax invoice for a completed repair_job and returns a 30-day
// signed URL. Hospital opens the URL in browser → prints to PDF for
// their records / ITC claim. Founder uses the same surface to back the
// monthly GSTR-3B filing.
@Singleton
class RepairInvoiceRepository @Inject constructor(
    private val supabase: SupabaseClient,
) {

    @Serializable
    data class InvoiceResult(
        @SerialName("ok") val ok: Boolean = false,
        @SerialName("invoice_number") val invoiceNumber: String? = null,
        @SerialName("invoice_url") val invoiceUrl: String? = null,
        @SerialName("gross_rupees") val grossRupees: Double? = null,
        @SerialName("taxable_value") val taxableValue: Double? = null,
        @SerialName("gst_total") val gstTotal: Double? = null,
        @SerialName("code") val code: String? = null,
        @SerialName("message") val message: String? = null,
    )

    suspend fun generate(jobId: String): Result<InvoiceResult> = runCatching {
        kotlinx.coroutines.withTimeout(30_000L) {
            val res = try {
                supabase.functions.invoke(
                    function = "generate_repair_invoice",
                    body = buildJsonObject {
                        put("job_id", JsonPrimitive(jobId))
                    },
                )
            } catch (rest: RestException) {
                error(rest.description ?: "Couldn't generate invoice")
            }
            val text = res.bodyAsText()
            val parsed = runCatching { JSON.decodeFromString(InvoiceResult.serializer(), text) }
                .getOrNull()
            if (!res.status.isSuccess()) {
                error(parsed?.message ?: "Couldn't generate invoice (HTTP ${res.status.value})")
            }
            parsed?.takeIf { it.ok && !it.invoiceUrl.isNullOrBlank() }
                ?: error(parsed?.message ?: "missing invoice url")
        }
    }

    private companion object {
        val JSON = Json { ignoreUnknownKeys = true }
    }
}
