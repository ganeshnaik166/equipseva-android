package com.equipseva.app.core.data.hospital

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * Read-only preventive-maintenance calendar for the calling hospital via
 * hospital_upcoming_pm(p_days_ahead) (round 507) — auth.uid()-scoped
 * server-side. Returns each scheduled asset whose next PM falls within the
 * window (overdue rows included, negative days_until_due), ordered
 * soonest-due first, excluding completed/cancelled schedules. Turns reactive
 * repairs into a proactive booking loop. Concrete @Singleton with constructor
 * injection; no @Binds module needed.
 */
@Singleton
class PmCalendarRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class PmScheduleItem(
        @SerialName("id") val id: String,
        @SerialName("equipment_type") val equipmentType: String? = null,
        @SerialName("equipment_brand") val equipmentBrand: String? = null,
        @SerialName("equipment_model") val equipmentModel: String? = null,
        @SerialName("equipment_serial") val equipmentSerial: String? = null,
        @SerialName("interval_days") val intervalDays: Int = 0,
        @SerialName("last_service_at") val lastServiceAt: String? = null,
        @SerialName("next_pm_due_at") val nextPmDueAt: String,
        // Fractional days remaining; negative when overdue.
        @SerialName("days_until_due") val daysUntilDue: Double = 0.0,
        // scheduled | upcoming | due | overdue (completed/cancelled filtered server-side).
        @SerialName("status") val status: String = "scheduled",
    )

    /**
     * @param daysAhead window (default 60). Overdue schedules are always
     * included regardless of the window; this only extends how far forward
     * upcoming PMs are surfaced.
     */
    suspend fun fetch(daysAhead: Int = 60): Result<List<PmScheduleItem>> = runCatching {
        client.postgrest.rpc(
            function = "hospital_upcoming_pm",
            parameters = buildJsonObject { put("p_days_ahead", JsonPrimitive(daysAhead)) },
        ).decodeList<PmScheduleItem>()
    }
}
