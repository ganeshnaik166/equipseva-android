package com.equipseva.app.core.data.logistics

import com.equipseva.app.BuildConfig
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Provider
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object LogisticsModule {

    @Provides
    @Singleton
    fun provideLogisticsJobRepository(
        supabase: Provider<SupabaseLogisticsJobRepository>,
        fake: Provider<FakeLogisticsJobRepository>,
    ): LogisticsJobRepository =
        if (BuildConfig.DEMO_MODE) fake.get() else supabase.get()
}
