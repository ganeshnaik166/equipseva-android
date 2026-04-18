package com.equipseva.app.core.data.cart

import androidx.room.Dao
import androidx.room.Query
import androidx.room.Upsert
import kotlinx.coroutines.flow.Flow

/** Phase 1 cart is single-user / on-device only. Server sync lands in Phase 3 via outbox. */
@Dao
interface CartDao {

    @Query("SELECT * FROM cart_line_items ORDER BY addedAtEpochMs DESC")
    fun observeAll(): Flow<List<CartItemEntity>>

    @Upsert
    suspend fun upsert(item: CartItemEntity)

    @Query("UPDATE cart_line_items SET quantity = quantity + 1 WHERE partId = :partId")
    suspend fun incrementQuantity(partId: String)

    @Query("UPDATE cart_line_items SET quantity = :quantity WHERE partId = :partId")
    suspend fun updateQuantity(partId: String, quantity: Int)

    @Query("DELETE FROM cart_line_items WHERE partId = :partId")
    suspend fun delete(partId: String)

    @Query("DELETE FROM cart_line_items")
    suspend fun clear()

    @Query("SELECT COALESCE(SUM(quantity), 0) FROM cart_line_items")
    fun count(): Flow<Int>

    @Query("SELECT * FROM cart_line_items WHERE partId = :partId LIMIT 1")
    suspend fun findByPartId(partId: String): CartItemEntity?
}
