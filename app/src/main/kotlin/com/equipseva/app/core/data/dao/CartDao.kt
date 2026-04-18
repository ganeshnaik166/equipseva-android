package com.equipseva.app.core.data.dao

import androidx.room.Dao
import androidx.room.Query
import androidx.room.Upsert
import com.equipseva.app.core.data.entities.CartEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface CartDao {
    @Query("SELECT * FROM cart_items WHERE userId = :userId ORDER BY updatedAt DESC")
    fun observeCart(userId: String): Flow<List<CartEntity>>

    @Upsert
    suspend fun upsert(item: CartEntity)

    @Query("DELETE FROM cart_items WHERE id = :id")
    suspend fun delete(id: String)

    @Query("DELETE FROM cart_items WHERE userId = :userId")
    suspend fun clear(userId: String)
}
