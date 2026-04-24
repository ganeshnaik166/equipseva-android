package com.equipseva.app.core.data.moderation

import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class ModerationModule {
    @Binds
    @Singleton
    abstract fun bindContentReportRepository(
        impl: SupabaseContentReportRepository,
    ): ContentReportRepository
}
