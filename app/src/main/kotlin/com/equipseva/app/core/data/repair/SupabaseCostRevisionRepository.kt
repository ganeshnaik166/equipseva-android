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
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

@Singleton
class SupabaseCostRevisionRepository @Inject constructor(
    private val client: SupabaseClient,
) : CostRevisionRepository {

    override suspend fun propose(
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

    override suspend fun decide(
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

    override suspend fun fetchPending(repairJobId: String): Result<CostRevision?> = runCatching {
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
     * pattern used by [SupabaseNotificationRepository.observeNotifications].
     */
    override fun observePending(repairJobId: String): Flow<CostRevision?> = callbackFlow {
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
            launch { client.realtime.removeChannel(ch) }
        }
    }.flowOn(Dispatchers.IO)

    private companion object {
        const val TABLE = "repair_job_cost_revisions"
    }
}
