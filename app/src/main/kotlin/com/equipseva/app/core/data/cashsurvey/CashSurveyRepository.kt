package com.equipseva.app.core.data.cashsurvey

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

// v2.1 PR-D1 — wraps the cash-payment-survey RPCs from
// 20260517100000_v21_cash_payment_survey. Hospital home calls
// fetchPending() on app open; if non-null the bottom-sheet asks the
// one-question survey and submit() POSTs the answer back.
@Singleton
class CashSurveyRepository @Inject constructor(
    private val supabase: SupabaseClient,
) {

    @Serializable
    data class PendingSurvey(
        @SerialName("repair_job_id") val repairJobId: String,
        @SerialName("job_number") val jobNumber: String,
        @SerialName("engineer_name") val engineerName: String,
        @SerialName("completed_at") val completedAt: String,
    )

    enum class Response(val storageKey: String) {
        AskedCash("asked_cash"),
        NoCash("no_cash"),
        Declined("declined"),
    }

    suspend fun fetchPending(): Result<PendingSurvey?> = runCatching {
        supabase.postgrest.rpc(
            function = "get_pending_cash_survey",
        ).decodeList<PendingSurvey>().firstOrNull()
    }

    suspend fun submit(repairJobId: String, response: Response): Result<Unit> = runCatching {
        supabase.postgrest.rpc(
            function = "submit_cash_survey",
            parameters = buildJsonObject {
                put("p_job", JsonPrimitive(repairJobId))
                put("p_response", JsonPrimitive(response.storageKey))
            },
        )
        Unit
    }
}
