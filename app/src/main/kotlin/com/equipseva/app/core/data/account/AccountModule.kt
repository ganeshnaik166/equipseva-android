package com.equipseva.app.core.data.account

import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class AccountModule {
    @Binds
    @Singleton
    abstract fun bindAccountDeletionRepository(
        impl: SupabaseAccountDeletionRepository,
    ): AccountDeletionRepository
}
