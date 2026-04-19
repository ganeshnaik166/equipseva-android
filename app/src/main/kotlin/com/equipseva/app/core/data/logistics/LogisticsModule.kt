package com.equipseva.app.core.data.logistics

import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class LogisticsModule {
    @Binds
    @Singleton
    abstract fun bindLogisticsJobRepository(impl: SupabaseLogisticsJobRepository): LogisticsJobRepository
}
