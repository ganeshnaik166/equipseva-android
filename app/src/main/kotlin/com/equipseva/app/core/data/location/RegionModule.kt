package com.equipseva.app.core.data.location

import com.equipseva.app.BuildConfig
import com.equipseva.app.core.observability.CrashReporter
import dagger.Binds
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class RegionModule {

    @Binds
    @Singleton
    abstract fun bindRegionAssetReader(impl: AndroidRegionAssetReader): RegionAssetReader

    @Binds
    @Singleton
    abstract fun bindRegionRepository(impl: SupabaseRegionRepository): RegionRepository

    companion object {
        @Provides
        fun provideRegionCatalogPolicy(): RegionCatalogPolicy =
            RegionCatalogPolicy(allowSynthetic = BuildConfig.DEBUG)

        @Provides
        fun provideRegionCatalogProblemReporter(crashReporter: CrashReporter): RegionCatalogProblemReporter =
            RegionCatalogProblemReporter { crashReporter.report(it, "region catalogue asset rejected") }
    }
}
