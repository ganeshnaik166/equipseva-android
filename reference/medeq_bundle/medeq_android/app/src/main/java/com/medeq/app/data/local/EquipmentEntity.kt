package com.medeq.app.data.local

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.Fts4
import androidx.room.PrimaryKey
import com.medeq.app.domain.Equipment

/**
 * Mirrors the SQLite schema produced by `medeq_pipeline/build_sqlite.py`.
 * Column names MUST match — Room uses the prepackaged DB as-is.
 */
@Entity(tableName = "equipment")
data class EquipmentEntity(
    @PrimaryKey @ColumnInfo(name = "id") val id: Long,
    @ColumnInfo(name = "source")           val source: String,
    @ColumnInfo(name = "udi")              val udi: String?,
    @ColumnInfo(name = "item_name")        val itemName: String,
    @ColumnInfo(name = "brand")            val brand: String?,
    @ColumnInfo(name = "model")            val model: String?,
    @ColumnInfo(name = "category")         val category: String,
    @ColumnInfo(name = "sub_category")     val subCategory: String?,
    @ColumnInfo(name = "type")             val type: String?,
    @ColumnInfo(name = "specifications")   val specifications: String?,
    @ColumnInfo(name = "price_inr_low")    val priceInrLow: Long?,
    @ColumnInfo(name = "price_inr_high")   val priceInrHigh: Long?,
    @ColumnInfo(name = "market")           val market: String?,
    @ColumnInfo(name = "image_search_url") val imageSearchUrl: String?,
    @ColumnInfo(name = "notes")            val notes: String?,
) {
    fun toDomain(): Equipment = Equipment(
        id = id,
        source = when (source) {
            "curated" -> Equipment.Source.CURATED
            "gudid"   -> Equipment.Source.GUDID
            else      -> Equipment.Source.REMOTE
        },
        udi = udi,
        itemName = itemName,
        brand = brand,
        model = model,
        category = category,
        subCategory = subCategory,
        type = type,
        specifications = specifications,
        priceInrLow = priceInrLow,
        priceInrHigh = priceInrHigh,
        market = market,
        imageSearchUrl = imageSearchUrl,
        notes = notes,
    )
}

/**
 * Phantom Room entity that matches the FTS5 virtual table created by the pipeline.
 * We don't insert through this — the SQL triggers in build_sqlite.py keep it
 * in sync with the equipment table. We only need it so Room recognises the
 * table during schema validation.
 */
@Fts4(contentEntity = EquipmentEntity::class)
@Entity(tableName = "equipment_fts")
data class EquipmentFts(
    @ColumnInfo(name = "item_name")      val itemName: String?,
    @ColumnInfo(name = "brand")          val brand: String?,
    @ColumnInfo(name = "model")          val model: String?,
    @ColumnInfo(name = "specifications") val specifications: String?,
    @ColumnInfo(name = "category")       val category: String?,
)
