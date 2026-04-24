package com.equipseva.app.core.data.repair

import com.equipseva.app.core.sync.OutboxKindHandler
import com.equipseva.app.core.sync.OutboxKinds
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import dagger.multibindings.IntoMap
import dagger.multibindings.StringKey
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class RepairModule {
    @Binds
    @Singleton
    abstract fun bindRepairJobRepository(impl: SupabaseRepairJobRepository): RepairJobRepository

    @Binds
    @Singleton
    abstract fun bindRepairBidRepository(impl: SupabaseRepairBidRepository): RepairBidRepository

    @Binds
    @IntoMap
    @StringKey(OutboxKinds.REPAIR_BID)
    abstract fun bindRepairBidOutboxHandler(impl: RepairBidOutboxHandler): OutboxKindHandler
}
