package com.equipseva.app.core.data.payouts

import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class EngineerPayoutModule {
    @Binds
    @Singleton
    abstract fun bind(impl: SupabaseEngineerPayoutRepository): EngineerPayoutRepository
}
