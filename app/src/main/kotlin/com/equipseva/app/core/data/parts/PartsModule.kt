package com.equipseva.app.core.data.parts

import com.equipseva.app.BuildConfig
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Provider
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object PartsModule {

    @Provides
    @Singleton
    fun provideSparePartsRepository(
        supabase: Provider<SupabaseSparePartsRepository>,
        fake: Provider<FakeSparePartsRepository>,
    ): SparePartsRepository =
        if (BuildConfig.DEMO_MODE) fake.get() else supabase.get()
}
