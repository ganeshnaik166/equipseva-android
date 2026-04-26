package com.medeq.app.data.local

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

@Database(
    entities = [EquipmentEntity::class, EquipmentFts::class],
    version = 1,
    exportSchema = true,
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun equipment(): EquipmentDao

    companion object {
        @Volatile private var INSTANCE: AppDatabase? = null

        /** Bundled SQLite filename in `app/src/main/assets/`. */
        private const val PREPACKAGED_ASSET = "equipment.db"
        private const val DB_NAME = "equipment.db"

        fun get(context: Context): AppDatabase = INSTANCE ?: synchronized(this) {
            INSTANCE ?: Room.databaseBuilder(
                context.applicationContext,
                AppDatabase::class.java,
                DB_NAME,
            )
                // Ship the SQLite from build_sqlite.py as a Room prepackaged DB.
                // First launch: Room copies it from /assets to the app's DB folder.
                .createFromAsset(PREPACKAGED_ASSET)
                // We never schema-migrate the bundled DB; just rebundle a new one
                // and bump @Database(version=...).
                .fallbackToDestructiveMigrationOnDowngrade()
                .build()
                .also { INSTANCE = it }
        }

        /**
         * Sanitises raw user input into a safe FTS5 MATCH query.
         *
         * - Strips FTS punctuation that would otherwise be interpreted as operators.
         * - Splits into terms and adds prefix wildcards so partial typing matches.
         *   "mind ven" -> "mind* ven*"
         */
        fun toFtsQuery(raw: String): String {
            val cleaned = raw
                .replace(Regex("[\"^*:()-]"), " ")
                .trim()
                .lowercase()
            if (cleaned.isEmpty()) return ""
            return cleaned.split(Regex("\\s+"))
                .filter { it.length >= 2 }
                .joinToString(" ") { "$it*" }
        }
    }
}
