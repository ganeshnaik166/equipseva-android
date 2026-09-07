package com.equipseva.app.core.sync.handlers

import android.util.Log
import com.equipseva.app.core.data.entities.OutboxEntryEntity
import com.equipseva.app.core.observability.CrashReporter
import com.equipseva.app.core.sync.OutboxKindHandler
import com.equipseva.app.core.sync.classifyOutboxError
import com.equipseva.app.core.util.BuildConfigValues
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.postgrest
import kotlinx.coroutines.CancellationException
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import javax.inject.Inject

/**
 * round3820 — files an uploaded repair photo in the §65B `evidence_ledger`
 * by calling round492's `register_evidence` RPC with the sha256 + size the
 * upload receipt recorded for the stored (EXIF-scrubbed) bytes.
 *
 * Why its own outbox kind rather than a tail step of the photo upload:
 *  - `register_evidence` is idempotent on (kind, source, id, sha), so
 *    retrying it is free; re-uploading a photo to retry it is not.
 *  - A permanent registration failure (RLS, a kind the server does not know)
 *    must never read as "photo upload failed" to the user, and must reach
 *    observability instead of being swallowed — evidence that silently fails
 *    to register is exactly the compliant-on-paper failure the ledger exists
 *    to end.
 *
 * Owner gate mirrors [PhotoUploadOutboxHandler]: the producer recorded at
 * upload time must be the signed-in user, or the RPC would stamp somebody
 * else's `producer_user_id` (it uses `auth.uid()`).
 *
 * Outcomes:
 *  - [OutboxKindHandler.Outcome.Retry]  — no session yet, network-shaped errors, 5xx.
 *  - [OutboxKindHandler.Outcome.GiveUp] — malformed payload, owner mismatch,
 *    4xx from the RPC (reported to [CrashReporter] first).
 */
class EvidenceRegisterOutboxHandler @Inject constructor(
    private val supabase: SupabaseClient,
    private val json: Json,
    private val crashReporter: CrashReporter,
) : OutboxKindHandler {

    override suspend fun handle(entry: OutboxEntryEntity): OutboxKindHandler.Outcome {
        val payload = runCatching { json.decodeFromString(EvidenceRegisterPayload.serializer(), entry.payload) }
            .getOrElse { return OutboxKindHandler.Outcome.GiveUp("Malformed evidence payload: ${it.message}") }

        val currentUid = supabase.auth.currentUserOrNull()?.id
            ?: return OutboxKindHandler.Outcome.Retry(
                IllegalStateException("No auth session — deferring evidence registration"),
            )
        if (currentUid != payload.producerUserId) {
            return OutboxKindHandler.Outcome.GiveUp(
                "Producer mismatch: queued as ${payload.producerUserId}, current auth is $currentUid",
            )
        }
        if (!SHA256_HEX.matches(payload.contentSha256) || payload.contentSizeBytes <= 0L) {
            return OutboxKindHandler.Outcome.GiveUp(
                "Evidence payload rejected client-side: sha=${payload.contentSha256.take(12)}… size=${payload.contentSizeBytes}",
            )
        }

        return try {
            val ledgerId = supabase.postgrest.rpc(
                function = "register_evidence",
                parameters = buildJsonObject {
                    put("p_evidence_kind", payload.evidenceKind)
                    put("p_source_kind", payload.sourceKind)
                    put("p_source_id", payload.sourceId)
                    put("p_content_sha256", payload.contentSha256)
                    put("p_content_size_bytes", payload.contentSizeBytes)
                    put("p_storage_url", payload.storageUrl)
                    put("p_producer_kind", payload.producerKind)
                    put("p_captured_at", payload.capturedAt)
                    put("p_platform_version", "android/${BuildConfigValues.versionName}")
                    put(
                        "p_metadata",
                        buildJsonObject {
                            put("mime_type", payload.mimeType)
                            put("captured_from", EvidenceRegisterPayload.CAPTURED_FROM_UPLOAD)
                            put("client", JsonPrimitive("android"))
                        },
                    )
                },
            ).data
            if (ledgerId.isBlank() || ledgerId == "null") {
                // The RPC returns the ledger uuid; a blank body means the call
                // "succeeded" without registering anything — treat as a defect.
                crashReporter.report(
                    IllegalStateException("register_evidence returned no id"),
                    "evidence_register: ${payload.evidenceKind} for ${payload.sourceKind}/${payload.sourceId}",
                )
                OutboxKindHandler.Outcome.GiveUp("register_evidence returned no ledger id")
            } else {
                Log.i(TAG, "Registered ${payload.evidenceKind} for ${payload.sourceId} as ledger ${ledgerId.trim('"')}")
                OutboxKindHandler.Outcome.Success
            }
        } catch (ce: CancellationException) {
            throw ce
        } catch (t: Throwable) {
            val outcome = classifyOutboxError(t)
            if (outcome is OutboxKindHandler.Outcome.GiveUp) {
                // Permanent: surface it. A photo that is on the job but has no
                // ledger row is a compliance gap someone must see.
                crashReporter.report(t, "evidence_register permanent failure: ${outcome.reason}")
            }
            outcome
        }
    }

    private companion object {
        const val TAG = "EvidenceRegister"
        val SHA256_HEX = Regex("^[0-9a-f]{64}$")
    }
}
