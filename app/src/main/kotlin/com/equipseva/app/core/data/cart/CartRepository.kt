package com.equipseva.app.core.data.cart

import kotlinx.coroutines.flow.Flow

/**
 * Local-first cart contract. Phase 1 is on-device only; a future outbox worker
 * will reconcile with Supabase in Phase 3.
 */
interface CartRepository {

    fun observe(): Flow<List<CartItem>>

    /** Total number of units across all cart lines (sum of quantities). */
    fun observeCount(): Flow<Int>

    /**
     * Add the part to the cart. If a line for this partId already exists, its
     * quantity is incremented by 1; otherwise a new line is inserted with qty 1.
     */
    suspend fun addOrIncrement(item: CartItemEntity): Result<Unit>

    suspend fun increment(partId: String): Result<Unit>

    suspend fun decrement(partId: String): Result<Unit>

    suspend fun setQuantity(partId: String, quantity: Int): Result<Unit>

    suspend fun remove(partId: String): Result<Unit>

    suspend fun clear(): Result<Unit>

    /**
     * Pull the authoritative cart from `cart_items` for [userId] and merge it
     * into local Room. Server wins on conflict — when a row exists both locally
     * and remotely, the remote quantity replaces the local one. Local-only
     * rows are left untouched (they are queued in the outbox and will land
     * server-side via the normal drain).
     *
     * Intended to run once per session start, not on every mutation.
     */
    suspend fun pullFromServer(userId: String): Result<Unit>
}
