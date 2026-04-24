package com.equipseva.app.core.data.engineers

import com.equipseva.app.BuildConfig
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Provider
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object EngineersModule {

    @Provides
    @Singleton
    fun provideEngineerRepository(
        supabase: Provider<SupabaseEngineerRepository>,
        fake: Provider<FakeEngineerRepository>,
    ): EngineerRepository =
        if (BuildConfig.DEMO_MODE) fake.get() else supabase.get()
}
