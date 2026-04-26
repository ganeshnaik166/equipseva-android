package com.medeq.app.data.local

import androidx.paging.PagingSource
import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface EquipmentDao {

    /** Curated India-priced rows first, then GUDID, ordered by relevance to query. */
    @Query("""
        SELECT e.* FROM equipment e
        JOIN equipment_fts f ON f.rowid = e.id
        WHERE equipment_fts MATCH :ftsQuery
        ORDER BY
            CASE e.source WHEN 'curated' THEN 0 WHEN 'gudid' THEN 1 ELSE 2 END,
            bm25(equipment_fts) ASC
        LIMIT :limit OFFSET :offset
    """)
    suspend fun search(ftsQuery: String, limit: Int = 50, offset: Int = 0): List<EquipmentEntity>

    @Query("""
        SELECT e.* FROM equipment e
        JOIN equipment_fts f ON f.rowid = e.id
        WHERE equipment_fts MATCH :ftsQuery
        ORDER BY
            CASE e.source WHEN 'curated' THEN 0 WHEN 'gudid' THEN 1 ELSE 2 END,
            bm25(equipment_fts) ASC
    """)
    fun searchPaged(ftsQuery: String): PagingSource<Int, EquipmentEntity>

    @Query("SELECT * FROM equipment WHERE id = :id")
    suspend fun byId(id: Long): EquipmentEntity?

    @Query("SELECT * FROM equipment WHERE udi = :udi LIMIT 1")
    suspend fun byUdi(udi: String): EquipmentEntity?

    @Query("SELECT * FROM equipment WHERE category = :category ORDER BY brand, model LIMIT :limit OFFSET :offset")
    suspend fun byCategory(category: String, limit: Int = 100, offset: Int = 0): List<EquipmentEntity>

    @Query("SELECT DISTINCT category FROM equipment ORDER BY category")
    fun categories(): Flow<List<String>>

    @Query("SELECT COUNT(*) FROM equipment")
    suspend fun count(): Int

    @Query("SELECT COUNT(*) FROM equipment WHERE source = :source")
    suspend fun countBySource(source: String): Int

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(rows: List<EquipmentEntity>)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(row: EquipmentEntity): Long
}
