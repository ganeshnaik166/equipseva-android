package com.equipseva.app.core.data.cart

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class RoomCartRepository @Inject constructor(
    private val dao: CartDao,
) : CartRepository {

    override fun observe(): Flow<List<CartItem>> =
        dao.observeAll().map { rows -> rows.map { it.toDomain() } }

    override fun observeCount(): Flow<Int> = dao.count()

    override suspend fun addOrIncrement(item: CartItemEntity): Result<Unit> = runCatching {
        val existing = dao.findByPartId(item.partId)
        if (existing != null) {
            dao.incrementQuantity(item.partId)
        } else {
            // Always pin qty=1 on insert — the caller's `quantity` is ignored on the
            // add-or-increment path so repeated adds behave predictably.
            dao.upsert(item.copy(quantity = 1))
        }
    }

    override suspend fun increment(partId: String): Result<Unit> = runCatching {
        dao.incrementQuantity(partId)
    }

    override suspend fun decrement(partId: String): Result<Unit> = runCatching {
        val existing = dao.findByPartId(partId) ?: return@runCatching
        val next = existing.quantity - 1
        if (next <= 0) {
            dao.delete(partId)
        } else {
            dao.updateQuantity(partId, next)
        }
    }

    override suspend fun setQuantity(partId: String, quantity: Int): Result<Unit> = runCatching {
        if (quantity <= 0) dao.delete(partId) else dao.updateQuantity(partId, quantity)
    }

    override suspend fun remove(partId: String): Result<Unit> = runCatching {
        dao.delete(partId)
    }

    override suspend fun clear(): Result<Unit> = runCatching {
        dao.clear()
    }
}
