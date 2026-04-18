package com.equipseva.app.core.data.parts

import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class PartsModule {
    @Binds
    @Singleton
    abstract fun bindSparePartsRepository(impl: SupabaseSparePartsRepository): SparePartsRepository
}
