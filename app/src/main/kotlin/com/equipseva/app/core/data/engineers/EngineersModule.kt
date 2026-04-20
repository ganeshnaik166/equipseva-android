package com.equipseva.app.core.data.engineers

import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class EngineersModule {
    @Binds
    @Singleton
    abstract fun bindEngineerRepository(impl: SupabaseEngineerRepository): EngineerRepository
}
