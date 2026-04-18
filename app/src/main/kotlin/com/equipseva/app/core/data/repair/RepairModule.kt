package com.equipseva.app.core.data.repair

import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class RepairModule {
    @Binds
    @Singleton
    abstract fun bindRepairJobRepository(impl: SupabaseRepairJobRepository): RepairJobRepository
}
