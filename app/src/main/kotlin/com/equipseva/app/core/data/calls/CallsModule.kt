package com.equipseva.app.core.data.calls

import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class CallsModule {
    @Binds
    @Singleton
    abstract fun bindVirtualCallRepository(
        impl: SupabaseVirtualCallRepository,
    ): VirtualCallRepository
}
