package com.equipseva.app.core.data.repair

import android.app.Application
import androidx.room.Room
import androidx.room.migration.Migration
import androidx.room.testing.MigrationTestHelper
import androidx.sqlite.db.SupportSQLiteDatabase
import androidx.sqlite.db.SupportSQLiteOpenHelper
import androidx.sqlite.db.framework.FrameworkSQLiteOpenHelperFactory
import androidx.test.core.app.ApplicationProvider
import androidx.test.platform.app.InstrumentationRegistry
import com.equipseva.app.core.data.AppDatabase
import com.equipseva.app.core.data.DatabaseModule
import com.equipseva.app.core.data.entities.DeviceTokenEntity
import com.equipseva.app.core.data.entities.OutboxEntryEntity
import com.equipseva.app.core.sync.OutboxKinds
import kotlinx.coroutines.runBlocking
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.SQLiteMode

/** Exported historical schema -> exact production migration -> generated Room validation. */
@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class, manifest = Config.NONE, sdk = [34])
@SQLiteMode(SQLiteMode.Mode.NATIVE)
class RepairPhotoDeliveryMigrationQaTest {
    private val context = ApplicationProvider.getApplicationContext<Application>()
    private val names = mutableListOf<String>()
    @get:Rule val helper = MigrationTestHelper(
        InstrumentationRegistry.getInstrumentation(), AppDatabase::class.java, emptyList(),
        object : SupportSQLiteOpenHelper.Factory {
            override fun create(configuration: SupportSQLiteOpenHelper.Configuration): SupportSQLiteOpenHelper {
                val actual = FrameworkSQLiteOpenHelperFactory().create(configuration)
                // Room 2.8's helper requests a full path; SupportSQLiteDriver's basename
                // comparison splits '/' only. Report that same absolute path on Windows,
                // while preserving the actual framework helper, schema and migration.
                return object : SupportSQLiteOpenHelper by actual {
                    override val databaseName: String?
                        get() = actual.databaseName?.let { configuration.context.getDatabasePath(it).absolutePath }
                }
            }
        },
    )

    @After fun cleanup() { names.forEach { context.deleteDatabase(it) } }
    private fun name() = "m${names.size}.db".also { names += it }

    // These fixtures intentionally contain the real shipped UID-only formats. There is no session inference.
    private val rows = listOf(
        OutboxEntryEntity(7, OutboxKinds.PHOTO_UPLOAD, """{"bucket":"repair-photos","objectPath":"owner/job/before.jpg","localFilePath":"/private/old-photo.jpg","mimeType":"image/jpeg","contextType":"repair_job_before","contextId":"job","uploaderUserId":"owner"}""", 100, 2, "old upload error"),
        OutboxEntryEntity(12, OutboxKinds.EVIDENCE_REGISTER, """{"evidenceKind":"photo_after","sourceKind":"repair_job","sourceId":"job","contentSha256":"${"a".repeat(64)}","contentSizeBytes":1024,"storageUrl":"repair-photos/owner/job/after.jpg","producerKind":"engineer","producerUserId":"owner","capturedAt":"2026-09-09T12:00:00Z","mimeType":"image/jpeg"}""", 101, 4, "old evidence error"),
        OutboxEntryEntity(20, OutboxKinds.PHOTO_UPLOAD, """{"contextType":"repair_job_before","contextId":"job"}""", 102, 0, null),
        OutboxEntryEntity(30, OutboxKinds.PHOTO_UPLOAD, "malformed {\n", 103, 1, "unknown owner"),
        OutboxEntryEntity(40, OutboxKinds.PHOTO_UPLOAD, """{"bucket":"kyc-docs","contextType":"kyc_doc","uploaderUserId":"owner"}""", 104, 3, null),
        OutboxEntryEntity(50, OutboxKinds.PHOTO_UPLOAD, """{"contextType":"repair_job_issue","uploaderUserId":"hospital"}""", 105, 1, "pending issue"),
        OutboxEntryEntity(60, OutboxKinds.CHAT_MESSAGE, """{"conversationId":"c","senderUserId":"owner","body":"private pending text"}""", 106, 2, null),
        OutboxEntryEntity(70, OutboxKinds.JOB_STATUS, """{"jobId":"job","newStatus":"Completed","actorUserId":"owner"}""", 107, 0, null),
        OutboxEntryEntity(80, OutboxKinds.REPAIR_BID, """{"jobId":"job","amountRupees":1500,"engineerUserId":"owner"}""", 108, 3, "pending bid"),
        OutboxEntryEntity(90, OutboxKinds.NOTIFICATION_READ, """{"notificationId":"n","userId":"owner"}""", 109, 1, null),
        OutboxEntryEntity(100, "UNKNOWN_FUTURE_KIND", "\u0000 preserved payload Ω हिंदी", 110, 0, "\nraw legacy stays unchanged"),
        OutboxEntryEntity(110, OutboxKinds.PHOTO_UPLOAD, """{"formatVersion":99,"ownerId":"foreign","sessionId":"foreign-session","generation":1}""", 111, 2, "unsupported future format"),
        OutboxEntryEntity(120, OutboxKinds.PHOTO_UPLOAD, """{"formatVersion":1,"ownerId":"owner","sessionId":"old-login","generation":7}""", 112, 1, "old generation"),
        OutboxEntryEntity(130, OutboxKinds.EVIDENCE_REGISTER, """{"producerUserId":"owner","contentSha256":"INVALID","storageUrl":"repair-photos/owner/job/../foreign.jpg","contentSizeBytes":-1}""", 113, 3, "invalid receipt"),
    )
    private val token = DeviceTokenEntity(0, "synthetic-device-token", "android", 1234567)

    private fun seed(db: SupportSQLiteDatabase) {
        rows.forEach {
            db.execSQL("INSERT INTO outbox(id,kind,payload,createdAt,attempts,lastError) VALUES(?,?,?,?,?,?)",
                arrayOf<Any?>(it.id, it.kind, it.payload, it.createdAt, it.attempts, it.lastError))
        }
        db.execSQL("INSERT INTO device_token(id,token,platform,registeredAt) VALUES(?,?,?,?)",
            arrayOf<Any>(token.id, token.token, token.platform, token.registeredAt))
    }

    private suspend fun assertPreserved(db: AppDatabase) {
        assertEquals(rows, db.outboxDao().nextBatch(1000))
        assertEquals(token, db.deviceTokenDao().current())
        val raw = db.openHelper.readableDatabase
        listOf("repair_photo_deliveries", "repair_photo_delivery_fence", "repair_photo_delivery_retired").forEach {
            raw.query("SELECT COUNT(*) FROM $it").use { cursor -> assertTrue(cursor.moveToFirst()); assertEquals(it, 0, cursor.getInt(0)) }
        }
    }

    private inline fun <T> AppDatabase.useDatabase(block: (AppDatabase) -> T): T =
        try { block(this) } finally { close() }

    @Test fun `v4 upgrade validates exact schema and preserves every legacy row without adoption`() = runBlocking<Unit> {
        val name = name()
        helper.createDatabase(name, 4).apply { seed(this); close() }
        helper.runMigrationsAndValidate(name, 5, true, DatabaseModule.MIGRATION_4_5).close()
        Room.databaseBuilder(context, AppDatabase::class.java, name)
            .addMigrations(*DatabaseModule.APP_MIGRATIONS).build().useDatabase { db ->
                assertPreserved(db)
                val newId = db.outboxDao().enqueue(OutboxEntryEntity(kind = OutboxKinds.CHAT_MESSAGE, payload = "next", createdAt = 200))
                assertTrue(newId > rows.maxOf { it.id })
                db.outboxDao().markFailed(newId, "safe existing behavior")
                assertEquals(1, db.outboxDao().nextBatch(1000).last().attempts)
                db.outboxDao().delete(newId)
                assertEquals(rows, db.outboxDao().nextBatch(1000))
            }
        Room.databaseBuilder(context, AppDatabase::class.java, name).build().useDatabase { assertPreserved(it) }
    }

    @Test fun `fresh v5 identity and schema validate against generated export`() = runBlocking<Unit> {
        val name = name()
        Room.databaseBuilder(context, AppDatabase::class.java, name).build().useDatabase { db ->
            val raw = db.openHelper.writableDatabase
            assertEquals(5, raw.version)
            val exported = context.assets.open("${AppDatabase::class.java.name}/5.json").bufferedReader().use { JSONObject(it.readText()) }
            val expectedHash = exported.getJSONObject("database").getString("identityHash")
            raw.query("SELECT identity_hash FROM room_master_table WHERE id=42").use {
                assertTrue(it.moveToFirst()); assertEquals(expectedHash, it.getString(0))
            }
            raw.query("SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'repair_photo_%' ORDER BY name").use {
                val tables = mutableListOf<String>()
                while (it.moveToNext()) tables += it.getString(0)
                assertEquals(listOf("repair_photo_deliveries", "repair_photo_delivery_fence", "repair_photo_delivery_retired"), tables)
            }
        }
        helper.runMigrationsAndValidate(name, 5, true, *DatabaseModule.APP_MIGRATIONS).close()
    }

    @Test fun `supported v3 chain preserves pending data and opens with the generated v5 database`() = runBlocking<Unit> {
        val name = name()
        helper.createDatabase(name, 3).apply { seed(this); close() }
        helper.runMigrationsAndValidate(name, 5, true, *DatabaseModule.APP_MIGRATIONS).close()
        Room.databaseBuilder(context, AppDatabase::class.java, name).build().useDatabase { assertPreserved(it) }
    }

    @Test fun `supported v2 chain preserves pending data and documents unchanged legacy extra table`() = runBlocking<Unit> {
        val name = name()
        helper.createDatabase(name, 2).apply { seed(this); close() }
        // Existing 2->3 drops cart_items, while exported v2 calls it cart_line_items.
        // Room permits this extra legacy table; this slice does not claim to repair or strictly drop it.
        helper.runMigrationsAndValidate(name, 5, false, *DatabaseModule.APP_MIGRATIONS).close()
        Room.databaseBuilder(context, AppDatabase::class.java, name).build().useDatabase { db ->
            assertPreserved(db)
            db.openHelper.readableDatabase.query("SELECT name FROM sqlite_master WHERE type='table' AND name='cart_line_items'").use {
                assertTrue(it.moveToFirst())
            }
        }
    }

    @Test fun `failure after actual migration DDL rolls back schema and preserves all v4 data`() = runBlocking<Unit> {
        val name = name()
        helper.createDatabase(name, 4).apply { seed(this); close() }
        val injected = object : Migration(4, 5) {
            override fun migrate(db: SupportSQLiteDatabase) {
                DatabaseModule.MIGRATION_4_5.migrate(db)
                error("qa_abort_after_actual_v5_ddl")
            }
        }
        val failing = Room.databaseBuilder(context, AppDatabase::class.java, name).addMigrations(injected).build()
        try {
            val result = runCatching { failing.openHelper.writableDatabase }
            assertTrue(result.isFailure)
            assertTrue(result.exceptionOrNull().toString().contains("qa_abort_after_actual_v5_ddl"))
        } finally { failing.close() }
        android.database.sqlite.SQLiteDatabase.openDatabase(context.getDatabasePath(name).absolutePath, null,
            android.database.sqlite.SQLiteDatabase.OPEN_READONLY).use { raw ->
                assertEquals(4, raw.version)
                raw.rawQuery("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name LIKE 'repair_photo_%'", null).use {
                    assertTrue(it.moveToFirst()); assertEquals(0, it.getInt(0))
                }
                raw.rawQuery("SELECT id,kind,payload,createdAt,attempts,lastError FROM outbox ORDER BY createdAt", null).use { cursor ->
                    val actual = mutableListOf<OutboxEntryEntity>()
                    while (cursor.moveToNext()) actual += OutboxEntryEntity(cursor.getLong(0), cursor.getString(1),
                        cursor.getString(2), cursor.getLong(3), cursor.getInt(4), if (cursor.isNull(5)) null else cursor.getString(5))
                    assertEquals(rows, actual)
                }
            }
        helper.runMigrationsAndValidate(name, 5, true, DatabaseModule.MIGRATION_4_5).close()
        Room.databaseBuilder(context, AppDatabase::class.java, name).build().useDatabase { assertPreserved(it) }
    }
}
