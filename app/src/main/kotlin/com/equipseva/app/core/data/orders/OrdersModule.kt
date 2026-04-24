package com.equipseva.app.core.data.orders

import com.equipseva.app.BuildConfig
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Provider
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object OrdersModule {

    @Provides
    @Singleton
    fun provideOrderRepository(
        supabase: Provider<SupabaseOrderRepository>,
        fake: Provider<FakeOrderRepository>,
    ): OrderRepository =
        if (BuildConfig.DEMO_MODE) fake.get() else supabase.get()
}
