package com.equipseva.app.core.data.reviews

import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class ReviewsModule {
    @Binds
    @Singleton
    abstract fun bindOrderReviewRepository(
        impl: SupabaseOrderReviewRepository,
    ): OrderReviewRepository
}
