package com.equipseva.app.core.data.cart

import android.util.Log
import com.equipseva.app.core.sync.OutboxEnqueuer
import com.equipseva.app.core.sync.OutboxKinds
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Columns
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class RoomCartRepository @Inject constructor(
    private val dao: CartDao,
    private val outboxEnqueuer: OutboxEnqueuer,
    private val supabase: SupabaseClient,
    private val json: Json,
) : CartRepository {

    override fun observe(): Flow<List<CartItem>> =
        dao.observeAll().map { rows -> rows.map { it.toDomain() } }

    override fun observeCount(): Flow<Int> = dao.count()

    override suspend fun addOrIncrement(item: CartItemEntity): Result<Unit> = runCatching {
        val existing = dao.findByPartId(item.partId)
        if (existing != null) {
            dao.incrementQuantity(item.partId)
            enqueueMutation(MutationKind.UPDATE_QTY, item.partId, existing.quantity + 1)
        } else {
            // Always pin qty=1 on insert — the caller's `quantity` is ignored on the
            // add-or-increment path so repeated adds behave predictably.
            dao.upsert(item.copy(quantity = 1))
            enqueueMutation(MutationKind.ADD, item.partId, 1)
        }
    }

    override suspend fun increment(partId: String): Result<Unit> = runCatching {
        dao.incrementQuantity(partId)
        val next = dao.findByPartId(partId)?.quantity
        enqueueMutation(MutationKind.UPDATE_QTY, partId, next)
    }

    override suspend fun decrement(partId: String): Result<Unit> = runCatching {
        val existing = dao.findByPartId(partId) ?: return@runCatching
        val next = existing.quantity - 1
        if (next <= 0) {
            dao.delete(partId)
            enqueueMutation(MutationKind.REMOVE, partId, null)
        } else {
            dao.updateQuantity(partId, next)
            enqueueMutation(MutationKind.UPDATE_QTY, partId, next)
        }
    }

    override suspend fun setQuantity(partId: String, quantity: Int): Result<Unit> = runCatching {
        if (quantity <= 0) {
            dao.delete(partId)
            enqueueMutation(MutationKind.REMOVE, partId, null)
        } else {
            dao.updateQuantity(partId, quantity)
            enqueueMutation(MutationKind.UPDATE_QTY, partId, quantity)
        }
    }

    override suspend fun remove(partId: String): Result<Unit> = runCatching {
        dao.delete(partId)
        enqueueMutation(MutationKind.REMOVE, partId, null)
    }

    override suspend fun clear(): Result<Unit> = runCatching {
        dao.clear()
        enqueueMutation(MutationKind.CLEAR, null, null)
    }

    /**
     * Server-authoritative reconcile. Pulls every `cart_items` row for the
     * current user, joining `spare_parts` for the display fields Room needs
     * (name, price, image). Server quantity overwrites the local row when
     * both sides have the same partId.
     *
     * Local-only rows are intentionally left alone — those are still queued
     * in the outbox and will land server-side on the next drain. We do not
     * delete them here, otherwise an offline-add right before sign-in would
     * be silently wiped.
     *
     * Single-shot: callers (CartSyncBootstrap) are expected to invoke this
     * once per session start. Subsequent mutations flow through the outbox
     * handler, not this method.
     */
    override suspend fun pullFromServer(userId: String): Result<Unit> = runCatching {
        val rows = supabase.from(SERVER_TABLE).select(
            columns = Columns.raw(
                "spare_part_id,quantity,updated_at," +
                    "spare_parts(id,name,price,images)",
            ),
        ) {
            filter { eq("user_id", userId) }
        }.decodeList<ServerCartRow>()

        val nowMs = System.currentTimeMillis()
        rows.forEach { row ->
            val part = row.sparePart ?: return@forEach
            val priceInPaise = (part.price * 100.0).toLong()
            val existing = dao.findByPartId(row.sparePartId)
            // Preserve the local addedAt so cart screen ordering is stable
            // across reconcile (most-recent-added stays at the top); only
            // mint a new timestamp for parts the local cart has never seen.
            val addedAt = existing?.addedAtEpochMs ?: nowMs
            dao.upsert(
                CartItemEntity(
                    partId = row.sparePartId,
                    name = part.name,
                    unitPriceInPaise = priceInPaise,
                    quantity = row.quantity,
                    imageUrl = part.images?.firstOrNull(),
                    addedAtEpochMs = addedAt,
                ),
            )
        }
        Log.i(TAG, "pullFromServer: reconciled ${rows.size} server cart rows for user=$userId")
        Unit
    }.onFailure { err ->
        Log.w(TAG, "pullFromServer failed for user=$userId", err)
    }

    @Serializable
    private data class ServerCartRow(
        @SerialName("spare_part_id") val sparePartId: String,
        val quantity: Int,
        @SerialName("updated_at") val updatedAt: String? = null,
        @SerialName("spare_parts") val sparePart: ServerSparePart? = null,
    )

    @Serializable
    private data class ServerSparePart(
        val id: String,
        val name: String,
        val price: Double,
        val images: List<String>? = null,
    )

    /**
     * Queue the mutation for future server reconcile. Fire-and-forget: the Room
     * write already committed, so a failure to enqueue must never surface back
     * to the caller and flip a successful local change into a Result.failure.
     *
     * If the user is signed out we skip the enqueue entirely — the outbox
     * handler owner-gate requires a userId, and there is no server endpoint
     * for an anonymous cart anyway.
     */
    private suspend fun enqueueMutation(kind: MutationKind, partId: String?, quantity: Int?) {
        val userId = supabase.auth.currentUserOrNull()?.id ?: return
        runCatching {
            val payload = json.encodeToString(
                CartMutationPayload.serializer(),
                CartMutationPayload(
                    kind = kind.wire,
                    userId = userId,
                    sparePartId = partId,
                    quantity = quantity,
                ),
            )
            outboxEnqueuer.enqueue(OutboxKinds.CART_MUTATION, payload)
        }.onFailure { err ->
            Log.w(TAG, "Failed to enqueue cart outbox (kind=${kind.wire}, partId=$partId)", err)
        }
    }

    private enum class MutationKind(val wire: String) {
        ADD("add"),
        UPDATE_QTY("update_qty"),
        REMOVE("remove"),
        CLEAR("clear"),
    }

    companion object {
        private const val TAG = "RoomCartRepository"
        private const val SERVER_TABLE = "cart_items"
    }
}
