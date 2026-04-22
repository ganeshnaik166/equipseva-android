package com.equipseva.app.core.data

import android.content.Context
import android.util.Log
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import com.equipseva.app.core.data.cart.CartDao
import com.equipseva.app.core.data.cart.CartItemEntity
import com.equipseva.app.core.data.dao.DeviceTokenDao
import com.equipseva.app.core.data.dao.MessageDao
import com.equipseva.app.core.data.dao.OrderDao
import com.equipseva.app.core.data.dao.OutboxDao
import com.equipseva.app.core.data.dao.RepairJobDao
import com.equipseva.app.core.data.entities.DeviceTokenEntity
import com.equipseva.app.core.data.entities.MessageEntity
import com.equipseva.app.core.data.entities.OrderEntity
import com.equipseva.app.core.data.entities.OutboxEntryEntity
import com.equipseva.app.core.data.entities.RepairJobEntity
import com.equipseva.app.core.data.secure.DbPassphraseStore
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import net.sqlcipher.database.SQLiteDatabase
import net.sqlcipher.database.SupportFactory
import java.io.File
import javax.inject.Singleton

@Database(
    entities = [
        CartItemEntity::class,
        OrderEntity::class,
        RepairJobEntity::class,
        MessageEntity::class,
        OutboxEntryEntity::class,
        DeviceTokenEntity::class,
    ],
    version = 2,
    exportSchema = true,
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun cartDao(): CartDao
    abstract fun orderDao(): OrderDao
    abstract fun repairJobDao(): RepairJobDao
    abstract fun messageDao(): MessageDao
    abstract fun outboxDao(): OutboxDao
    abstract fun deviceTokenDao(): DeviceTokenDao
}

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {

    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): AppDatabase {
        SQLiteDatabase.loadLibs(context)

        // Plain-text DB from prior builds cannot be opened by SQLCipher. The
        // DB is a local cache + outbox (no canonical state), so the safe
        // upgrade path is to delete it on first encrypted open. Pending
        // outbox entries are lost; release notes call this out.
        val plain = context.getDatabasePath(DB_NAME)
        if (plain.exists() && !isEncrypted(plain)) {
            Log.w(TAG, "Found plain-text ${plain.name}; wiping for encrypted re-open.")
            plain.delete()
            File(plain.parentFile, "${plain.name}-shm").delete()
            File(plain.parentFile, "${plain.name}-wal").delete()
        }

        val passphrase = DbPassphraseStore(context).getOrCreate()
        val factory = SupportFactory(passphrase, null, /* clearPassphrase = */ true)
        return Room.databaseBuilder(context, AppDatabase::class.java, DB_NAME)
            .openHelperFactory(factory)
            .fallbackToDestructiveMigration()
            .build()
    }

    private const val DB_NAME = "equipseva.db"
    private const val TAG = "AppDatabase"

    /** SQLite magic header is "SQLite format 3\u0000". Encrypted files are random bytes. */
    private fun isEncrypted(file: File): Boolean {
        if (file.length() < 16L) return true
        return runCatching {
            file.inputStream().use { input ->
                val header = ByteArray(16)
                input.read(header)
                String(header, Charsets.US_ASCII) != "SQLite format 3\u0000"
            }
        }.getOrDefault(true)
    }

    @Provides fun cart(db: AppDatabase): CartDao = db.cartDao()
    @Provides fun orders(db: AppDatabase): OrderDao = db.orderDao()
    @Provides fun jobs(db: AppDatabase): RepairJobDao = db.repairJobDao()
    @Provides fun messages(db: AppDatabase): MessageDao = db.messageDao()
    @Provides fun outbox(db: AppDatabase): OutboxDao = db.outboxDao()
    @Provides fun deviceToken(db: AppDatabase): DeviceTokenDao = db.deviceTokenDao()
}
