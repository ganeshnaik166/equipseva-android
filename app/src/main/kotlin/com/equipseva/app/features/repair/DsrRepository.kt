package com.equipseva.app.features.repair

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject

/**
 * round3812 — client for the Digital Service Report (DSR) backend that
 * round494 shipped and no client ever called (`dsr_reports` had ZERO rows
 * in production despite the table, four RPCs, RLS and grants all being
 * live). ROADMAP_v04 Phase 3 item #6.
 *
 * This is the root unblocker for three already-shipped surfaces: the
 * Predictive PM calendar projects from signed DSRs, the NABH audit bundle
 * (`export_nabh_bundle`) renders them, and the §65B evidence pipeline
 * hangs off their signature events. All three have been structurally
 * empty because nothing ever wrote a DSR.
 *
 * Server contract (verified by a live rolled-back probe against prod
 * before this file was written — submit → 'pending_hospital_sign', both
 * parties can read via dsr_for_job, hospital_sign_dsr → 'signed'):
 *  - submit_dsr: engineer-with-accepted-bid only (server-enforced);
 *    work_summary CHECK length 20..5000; jsonb readings/parts arrays are
 *    coalesced server-side, so this V1 client sends `[]` and captures
 *    the pass/fail + calibration verdicts plus the narrative. Structured
 *    per-parameter readings and the Aadhaar eSign layer are the
 *    follow-on (eSign needs the NSDL integration — founder scope).
 *  - resubmission REPLACES the previous DSR for the job (server deletes
 *    the old row), which also resets a pending hospital signature.
 *  - hospital_sign_dsr: job's hospital only; signer name/role min 3
 *    chars; only from status 'pending_hospital_sign'.
 */
@Singleton
class DsrRepository @Inject constructor(
    private val client: SupabaseClient,
) {

    /**
     * Subset of dsr_for_job's columns — the app-wide serializer sets
     * ignoreUnknownKeys, so the jsonb payload columns the V1 UI doesn't
     * render (pre_post_readings, parts_replaced) are simply skipped.
     */
    @Serializable
    data class Dsr(
        val id: String,
        val status: String,
        @SerialName("engineer_signature_at") val engineerSignatureAt: String,
        @SerialName("hospital_signature_at") val hospitalSignatureAt: String? = null,
        @SerialName("iec_62353_passed") val iec62353Passed: Boolean? = null,
        @SerialName("calibration_within_oem") val calibrationWithinOem: Boolean? = null,
        @SerialName("work_summary") val workSummary: String,
        val recommendations: String? = null,
    ) {
        val isSigned: Boolean get() = status == STATUS_SIGNED
        val isPendingSign: Boolean get() = status == STATUS_PENDING_SIGN
    }

    suspend fun fetch(jobId: String): Result<Dsr?> = runCatching {
        client.postgrest.rpc(
            function = "dsr_for_job",
            parameters = buildJsonObject {
                put("p_repair_job_id", JsonPrimitive(jobId))
            },
        ).decodeList<Dsr>().firstOrNull()
    }

    suspend fun submit(
        jobId: String,
        workSummary: String,
        // null = electrical safety test not applicable (cosmetic repair)
        iec62353Passed: Boolean?,
        calibrationPerformed: Boolean,
        // meaningful only when calibrationPerformed; server stores as-is
        calibrationWithinOem: Boolean?,
        calibrationLabRef: String?,
        recommendations: String?,
    ): Result<String> = runCatching {
        val raw = client.postgrest.rpc(
            function = "submit_dsr",
            parameters = buildJsonObject {
                put("p_repair_job_id", JsonPrimitive(jobId))
                put("p_pre_post_readings", buildJsonArray {})
                put("p_iec_62353_passed", iec62353Passed?.let(::JsonPrimitive) ?: JsonNull)
                put("p_iec_62353_readings", buildJsonArray {})
                put("p_calibration_performed", JsonPrimitive(calibrationPerformed))
                put(
                    "p_calibration_within_oem",
                    if (calibrationPerformed) {
                        calibrationWithinOem?.let(::JsonPrimitive) ?: JsonNull
                    } else {
                        JsonNull
                    },
                )
                put("p_calibration_readings", buildJsonArray {})
                put(
                    "p_calibration_lab_ref",
                    // Gated on calibrationPerformed, like within_oem above.
                    // Review finding (round3812): the form retains a typed
                    // lab ref in saved state after the calibration toggle is
                    // switched off; sending it unconditionally would persist
                    // calibration_performed=false WITH a lab reference — a
                    // self-contradictory NABH compliance record (the server
                    // has no CHECK tying the two together).
                    if (calibrationPerformed) {
                        calibrationLabRef?.trim()?.takeIf { it.isNotEmpty() }
                            ?.let(::JsonPrimitive) ?: JsonNull
                    } else {
                        JsonNull
                    },
                )
                put("p_parts_replaced", buildJsonArray {})
                put("p_work_summary", JsonPrimitive(workSummary.trim()))
                put(
                    "p_recommendations",
                    recommendations?.trim()?.takeIf { it.isNotEmpty() }
                        ?.let(::JsonPrimitive) ?: JsonNull,
                )
            },
        ).data
        raw.trim().trim('"')
    }

    suspend fun sign(dsrId: String, signerName: String, signerRole: String): Result<Unit> =
        runCatching {
            client.postgrest.rpc(
                function = "hospital_sign_dsr",
                parameters = buildJsonObject {
                    put("p_dsr_id", JsonPrimitive(dsrId))
                    put("p_signer_name", JsonPrimitive(signerName.trim()))
                    put("p_signer_role", JsonPrimitive(signerRole.trim()))
                },
            )
            Unit
        }

    companion object {
        const val STATUS_PENDING_SIGN = "pending_hospital_sign"
        const val STATUS_SIGNED = "signed"
    }
}

/**
 * Client-side mirrors of the server constraints, so the form can explain
 * the rule instead of surfacing a raw 22023/23514. Kept as pure functions
 * for unit testing (the r1505 pattern: server CHECK mirrors are
 * test-locked so schema drift breaks the build, not production).
 */
object DsrValidators {
    const val WORK_SUMMARY_MIN = 20   // dsr_reports CHECK lower bound
    const val WORK_SUMMARY_MAX = 5000 // dsr_reports CHECK upper bound
    const val SIGNER_MIN = 3          // hospital_sign_dsr min for name AND role

    fun workSummaryProblem(input: String): DsrFieldProblem? {
        val trimmed = input.trim()
        return when {
            trimmed.length < WORK_SUMMARY_MIN -> DsrFieldProblem.TooShort
            trimmed.length > WORK_SUMMARY_MAX -> DsrFieldProblem.TooLong
            else -> null
        }
    }

    fun signerFieldOk(input: String): Boolean = input.trim().length >= SIGNER_MIN
}

enum class DsrFieldProblem { TooShort, TooLong }
