package com.equipseva.app.core.data.payouts

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * Engineer-facing TDS (section 194-O) statement via my_tds_summary() (r490):
 * one row per fiscal quarter for a financial year, auth.uid()-scoped. Called
 * with no fiscal year → the RPC defaults to the CURRENT Indian FY server-side.
 * Read-only; concrete @Singleton with constructor injection.
 */
@Singleton
class TdsSummaryRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class TdsQuarterRow(
        @SerialName("fiscal_year") val fiscalYear: String,
        @SerialName("fy_quarter") val fyQuarter: String,
        @SerialName("total_gross_rupees") val grossRupees: Double = 0.0,
        @SerialName("total_tds_rupees") val tdsRupees: Double = 0.0,
        @SerialName("total_net_payable_rupees") val netPayableRupees: Double = 0.0,
        @SerialName("deduction_count") val deductionCount: Long = 0,
    )

    /** [fiscalYear] null → current FY (server-side default). */
    suspend fun fetchTdsSummary(fiscalYear: String? = null): Result<List<TdsQuarterRow>> = runCatching {
        client.postgrest.rpc(
            function = "my_tds_summary",
            parameters = buildJsonObject {
                if (fiscalYear != null) put("p_fiscal_year", JsonPrimitive(fiscalYear))
            },
        ).decodeList<TdsQuarterRow>()
    }
}
