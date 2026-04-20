package com.equipseva.app.core.data.rfq

import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class RfqModule {
    @Binds
    @Singleton
    abstract fun bindRfqRepository(impl: SupabaseRfqRepository): RfqRepository
}
