package com.equipseva.app.core.data.founder

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Generic reader for the founder "key-value" summary RPCs (round 1199+ style):
 * founder_platform_pulse + the founder_*_summary family all RETURN
 * (metric, value_text, value_numeric?, ord?), so one repo + one screen surface
 * them all. Each is SECURITY DEFINER gated by is_founder() server-side; a
 * non-founder gets an error. Read-only. The supabase client runs with
 * ignoreUnknownKeys, so RPCs with slightly different column sets still decode.
 */
@Singleton
class FounderMetricRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class Metric(
        @SerialName("metric") val metric: String = "",
        @SerialName("value_text") val valueText: String? = null,
        @SerialName("value_numeric") val valueNumeric: Double? = null,
        // founder_catalog_coverage_summary names its numeric column `value_num`
        // (bigint), not `value_numeric` — decode it too so its rows don't all
        // render "—". Other summaries use value_text/value_numeric (null here).
        @SerialName("value_num") val valueNum: Long? = null,
        @SerialName("ord") val ord: Int? = null,
    )

    /** [rpcName] must be a caller-safe, code-listed founder key-value RPC (never
     *  user input) — see FOUNDER_METRIC_DASHBOARDS. */
    suspend fun fetch(rpcName: String): Result<List<Metric>> = runCatching {
        client.postgrest
            .rpc(function = rpcName)
            .decodeList<Metric>()
            .sortedBy { it.ord ?: Int.MAX_VALUE }
    }
}
