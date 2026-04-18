package com.equipseva.app.core.data.dao

import androidx.room.Dao
import androidx.room.Query
import androidx.room.Upsert
import com.equipseva.app.core.data.entities.DeviceTokenEntity

@Dao
interface DeviceTokenDao {
    @Query("SELECT * FROM device_token WHERE id = 0")
    suspend fun current(): DeviceTokenEntity?

    @Upsert
    suspend fun upsert(entity: DeviceTokenEntity)

    @Query("DELETE FROM device_token")
    suspend fun clear()
}
