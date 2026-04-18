package com.equipseva.app.core.data.dao

import androidx.room.Dao
import androidx.room.Query
import androidx.room.Upsert
import com.equipseva.app.core.data.entities.RepairJobEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface RepairJobDao {
    @Query("SELECT * FROM repair_jobs WHERE engineerId = :engineerId ORDER BY updatedAt DESC")
    fun observeForEngineer(engineerId: String): Flow<List<RepairJobEntity>>

    @Query("SELECT * FROM repair_jobs WHERE hospitalId = :hospitalId ORDER BY updatedAt DESC")
    fun observeForHospital(hospitalId: String): Flow<List<RepairJobEntity>>

    @Query("SELECT * FROM repair_jobs WHERE id = :id")
    fun observeJob(id: String): Flow<RepairJobEntity?>

    @Upsert
    suspend fun upsert(job: RepairJobEntity)

    @Upsert
    suspend fun upsertAll(jobs: List<RepairJobEntity>)
}
