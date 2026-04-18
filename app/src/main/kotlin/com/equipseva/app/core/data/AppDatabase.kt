package com.equipseva.app.core.data

import android.content.Context
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
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
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
    fun provideDatabase(@ApplicationContext context: Context): AppDatabase =
        Room.databaseBuilder(context, AppDatabase::class.java, "equipseva.db")
            .fallbackToDestructiveMigration(dropAllTables = false)
            .build()

    @Provides fun cart(db: AppDatabase): CartDao = db.cartDao()
    @Provides fun orders(db: AppDatabase): OrderDao = db.orderDao()
    @Provides fun jobs(db: AppDatabase): RepairJobDao = db.repairJobDao()
    @Provides fun messages(db: AppDatabase): MessageDao = db.messageDao()
    @Provides fun outbox(db: AppDatabase): OutboxDao = db.outboxDao()
    @Provides fun deviceToken(db: AppDatabase): DeviceTokenDao = db.deviceTokenDao()
}
