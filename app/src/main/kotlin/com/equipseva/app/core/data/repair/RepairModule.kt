package com.equipseva.app.core.data.repair

import com.equipseva.app.BuildConfig
import com.equipseva.app.core.sync.OutboxKindHandler
import com.equipseva.app.core.sync.OutboxKinds
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import dagger.multibindings.IntoMap
import dagger.multibindings.StringKey
import javax.inject.Provider
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object RepairModule {

    @Provides
    @Singleton
    fun provideRepairJobRepository(
        supabase: Provider<SupabaseRepairJobRepository>,
        fake: Provider<FakeRepairJobRepository>,
    ): RepairJobRepository =
        if (BuildConfig.DEMO_MODE) fake.get() else supabase.get()

    @Provides
    @Singleton
    fun provideRepairBidRepository(
        supabase: Provider<SupabaseRepairBidRepository>,
        fake: Provider<FakeRepairBidRepository>,
    ): RepairBidRepository =
        if (BuildConfig.DEMO_MODE) fake.get() else supabase.get()

    // Outbox handlers stay wired to the Supabase-side implementations regardless
    // of DEMO_MODE — the outbox itself doesn't have demo content to drain.
    @Provides
    @IntoMap
    @StringKey(OutboxKinds.REPAIR_BID)
    fun provideRepairBidOutboxHandler(impl: RepairBidOutboxHandler): OutboxKindHandler = impl

    @Provides
    @IntoMap
    @StringKey(OutboxKinds.JOB_STATUS)
    fun provideJobStatusOutboxHandler(impl: JobStatusOutboxHandler): OutboxKindHandler = impl
}
