package com.equipseva.app.core.data.repair

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Order
import io.github.jan.supabase.postgrest.query.filter.FilterOperator
import io.github.jan.supabase.realtime.PostgresAction
import io.github.jan.supabase.realtime.channel
import io.github.jan.supabase.realtime.postgresChangeFlow
import io.github.jan.supabase.realtime.realtime
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * Engineer ↔ Hospital scope-change negotiation. Drives the
 * propose_cost_revision / decide_cost_revision SECURITY DEFINER RPCs
 * server-side; observePending streams the table directly via
 * Postgrest realtime so the hospital banner / engineer "awaiting
 * approval" state are eventually-consistent without a manual refresh.
 */
@Singleton
class CostRevisionRepository @Inject constructor(
    private val client: SupabaseClient,
) {

    // Singleton-lifetime scope so the realtime removeChannel call
    // survives the callbackFlow cancellation that triggers awaitClose.
    // Without this, the channel persists on the singleton supabase
    // client until websocket reconnect / process death. Mirrors
    // ChatRepository.cleanupScope from PR #637.
    private val cleanupScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    /** Engineer-only. Server enforces side-identity + status gates. */
    suspend fun propose(
        repairJobId: String,
        revisedAmountRupees: Double,
        reason: String,
    ): Result<CostRevision> = runCatching {
        val raw = client.postgrest.rpc(
            function = "propose_cost_revision",
            parameters = buildJsonObject {
                put("p_job_id", JsonPrimitive(repairJobId))
                put("p_revised_amount", JsonPrimitive(revisedAmountRupees))
                put("p_reason", JsonPrimitive(reason))
            },
        )
        raw.decodeAs<CostRevisionDto>().toDomain()
    }

    /** Hospital-only. Server enforces side-identity + status gate. */
    suspend fun decide(
        revisionId: String,
        approve: Boolean,
    ): Result<CostRevision> = runCatching {
        val raw = client.postgrest.rpc(
            function = "decide_cost_revision",
            parameters = buildJsonObject {
                put("p_revision_id", JsonPrimitive(revisionId))
                put("p_approve", JsonPrimitive(approve))
            },
        )
        raw.decodeAs<CostRevisionDto>().toDomain()
    }

    /** Latest pending revision for the job, or null if none in flight. */
    suspend fun fetchPending(repairJobId: String): Result<CostRevision?> = runCatching {
        client.from(TABLE)
            .select {
                filter {
                    eq("repair_job_id", repairJobId)
                    eq("status", CostRevisionStatus.Proposed.key)
                }
                order("created_at", order = Order.DESCENDING)
                limit(count = 1)
            }
            .decodeList<CostRevisionDto>()
            .firstOrNull()
            ?.toDomain()
    }

    /**
     * Realtime sub on the `repair_job_cost_revisions` table filtered to this
     * job. Re-fetches the pending row on every change event so the UI
     * always reflects the latest status (including transitions to
     * approved/rejected/expired which collapse the banner). Matches the
     * pattern used by [com.equipseva.app.core.data.notifications.NotificationRepository.observeNotifications].
     *
     * Emits null when the row is absent / approved / rejected / expired so
     * the UI banner can hide automatically.
     */
    fun observePending(repairJobId: String): Flow<CostRevision?> = callbackFlow {
        suspend fun refresh() {
            runCatching { fetchPending(repairJobId).getOrNull() }
                .onSuccess { trySend(it) }
        }
        // Prime so the UI doesn't have to wait for the first realtime event.
        refresh()

        val ch = client.channel("cost-revisions:$repairJobId")
        val changes = ch.postgresChangeFlow<PostgresAction>(schema = "public") {
            table = TABLE
            filter("repair_job_id", FilterOperator.EQ, repairJobId)
        }
        val job = launch {
            changes.collect { _ -> refresh() }
        }
        ch.subscribe()
        awaitClose {
            job.cancel()
            cleanupScope.launch { client.realtime.removeChannel(ch) }
        }
    }.flowOn(Dispatchers.IO)

    private companion object {
        const val TABLE = "repair_job_cost_revisions"
    }
}
