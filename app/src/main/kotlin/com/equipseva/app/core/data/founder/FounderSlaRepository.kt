package com.equipseva.app.core.data.founder

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * Founder engineer-SLA board (round 506): engineer_sla_board(p_days, p_limit)
 * ranks engineers by SLA health over a window — dispute rate, on-time %, SLA
 * breaches, current risk score/band and tier. is_founder()-gated server-side.
 * Read-only.
 */
@Singleton
class FounderSlaRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class SlaRow(
        @SerialName("engineer_email") val engineerEmail: String? = null,
        @SerialName("jobs_completed_window") val jobsCompletedWindow: Int = 0,
        @SerialName("jobs_disputed_window") val jobsDisputedWindow: Int = 0,
        @SerialName("dispute_rate_pct") val disputeRatePct: Double? = null,
        @SerialName("avg_accept_to_arrival_hrs") val avgAcceptToArrivalHrs: Double? = null,
        @SerialName("avg_arrival_to_complete_hrs") val avgArrivalToCompleteHrs: Double? = null,
        @SerialName("sla_breaches") val slaBreaches: Int = 0,
        @SerialName("on_time_pct") val onTimePct: Double? = null,
        @SerialName("current_risk_score") val currentRiskScore: Int? = null,
        @SerialName("current_risk_band") val currentRiskBand: String? = null,
        @SerialName("current_tier") val currentTier: String? = null,
    )

    suspend fun board(days: Int = 30, limit: Int = 100): Result<List<SlaRow>> = runCatching {
        client.postgrest.rpc(
            function = "engineer_sla_board",
            parameters = buildJsonObject {
                put("p_days", JsonPrimitive(days))
                put("p_limit", JsonPrimitive(limit))
            },
        ).decodeList<SlaRow>()
    }
}
