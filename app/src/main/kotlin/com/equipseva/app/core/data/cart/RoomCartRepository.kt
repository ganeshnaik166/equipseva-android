package com.equipseva.app.core.data.cart

import android.util.Log
import com.equipseva.app.core.sync.OutboxEnqueuer
import com.equipseva.app.core.sync.OutboxKinds
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
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
    }
}
