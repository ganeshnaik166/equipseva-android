package com.equipseva.app.core.data.engineers

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * The calling engineer's own 30-day SLA scorecard via my_sla_card() (round
 * 506) — auth.uid()-scoped server-side over accepted bids. Read-only; drives
 * the engineer "My SLA" performance screen. No params. Concrete @Singleton
 * with constructor injection; no @Binds module needed.
 */
@Singleton
class SlaCardRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class SlaCard(
        @SerialName("jobs_completed_window") val jobsCompletedWindow: Int = 0,
        @SerialName("jobs_disputed_window") val jobsDisputedWindow: Int = 0,
        @SerialName("dispute_rate_pct") val disputeRatePct: Double = 0.0,
        // Averages can be NULL when the window has no completed jobs to
        // measure the leg from.
        @SerialName("avg_accept_to_arrival_hrs") val avgAcceptToArrivalHrs: Double? = null,
        @SerialName("avg_arrival_to_complete_hrs") val avgArrivalToCompleteHrs: Double? = null,
        @SerialName("sla_breaches") val slaBreaches: Int = 0,
        @SerialName("on_time_pct") val onTimePct: Double = 100.0,
    )

    suspend fun fetch(): Result<SlaCard?> = runCatching {
        client.postgrest
            .rpc(function = "my_sla_card")
            .decodeList<SlaCard>()
            .firstOrNull()
    }
}
