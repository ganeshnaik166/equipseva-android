package com.equipseva.app.features.amc

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * Read-side repo for the hospital's Predictive PM (preventive
 * maintenance) calendar (round507, shipped 2026-06 as v0.4 Phase 4 #4).
 * This repo + [HospitalPmCalendarScreen] (round3770) is the first client
 * of that backend — no Android screen had ever called it.
 *
 * ⚠️ EXPECT AN EMPTY CALENDAR IN PRODUCTION TODAY, and do not treat that
 * as a bug in this repo. Corrected in round3794 — an earlier version of
 * this comment claimed "a daily cron (`recompute_all_pm_schedules_daily`,
 * 04:00 IST) walks every hospital's signed DSRs and forward-projects the
 * next PM due date". That was verified against production and is FALSE
 * on two independent counts:
 *
 *  1. That cron job does not exist. `pg_cron` is not installed on this
 *     Supabase project at all (no `cron` schema), which is deliberate —
 *     scheduling is done by a Free-tier substitute: GitHub Actions
 *     (`.github/workflows/cron-tick-{hourly,daily}.yml`) POSTing to the
 *     `cron-tick` edge function. But `cron-tick` covers only 11 of the
 *     31 jobs the migrations declare, and `recompute_all_pm_schedules`
 *     is NOT one of them. Every `cron.schedule(...)` call site is either
 *     guarded on `extname='pg_cron'` or wrapped in
 *     `EXCEPTION WHEN OTHERS`, so the whole set failed silently and
 *     nothing surfaced.
 *  2. Even with the cron running it would project from signed DSRs, and
 *     `dsr_reports` has ZERO rows — there is no DSR-submission path in
 *     the app producing them (same root cause as the round3786
 *     evidence_ledger finding).
 *
 * Live figures at the time of writing: `equipment_pm_schedule` 0 rows,
 * `dsr_reports` 0 rows, `equipment_pm_intervals` 5 rows (seed only).
 *
 * So the screen is correct and honest — it renders its empty state — but
 * it cannot show data until either the PM recompute is added to a
 * `cron-tick` slot or a DSR-submission path exists. Both are backend
 * work, tracked outside this file; enabling ~14 never-run sweeps at once
 * against months of accumulated rows is a deliberate operational
 * decision, not a code cleanup.
 */
@Singleton
class HospitalPmCalendarRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class PmScheduleItem(
        val id: String,
        @SerialName("equipment_type") val equipmentType: String,
        @SerialName("equipment_brand") val equipmentBrand: String? = null,
        @SerialName("equipment_model") val equipmentModel: String? = null,
        @SerialName("equipment_serial") val equipmentSerial: String? = null,
        @SerialName("interval_days") val intervalDays: Int,
        @SerialName("last_service_at") val lastServiceAt: String? = null,
        @SerialName("next_pm_due_at") val nextPmDueAt: String,
        @SerialName("days_until_due") val daysUntilDue: Double,
        val status: String,
    )

    /**
     * Best-effort forward-recompute for just this hospital, called
     * before [fetchUpcoming] so a DSR signed minutes ago shows up
     * immediately instead of waiting for the next 04:00 IST cron tick.
     * `recompute_pm_schedule` is idempotent (ON CONFLICT DO UPDATE) so
     * calling it more than once a day is harmless — safe to run on
     * every cold-load + pull-to-refresh.
     */
    suspend fun recomputeSchedule(hospitalUserId: String): Result<Int> = runCatching {
        val raw = client.postgrest.rpc(
            function = "recompute_pm_schedule",
            parameters = buildJsonObject { put("p_hospital_user_id", JsonPrimitive(hospitalUserId)) },
        ).data
        raw.trim().trim('"').toIntOrNull() ?: 0
    }

    suspend fun fetchUpcoming(daysAhead: Int = 60): Result<List<PmScheduleItem>> = runCatching {
        client.postgrest.rpc(
            function = "hospital_upcoming_pm",
            parameters = buildJsonObject { put("p_days_ahead", JsonPrimitive(daysAhead)) },
        ).decodeList<PmScheduleItem>()
    }
}
