package com.equipseva.app.core.data.cart

import com.equipseva.app.core.sync.OutboxKindHandler
import com.equipseva.app.core.sync.OutboxKinds
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import dagger.multibindings.IntoMap
import dagger.multibindings.StringKey
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class CartModule {
    @Binds
    @Singleton
    abstract fun bindCartRepository(impl: RoomCartRepository): CartRepository

    @Binds
    @IntoMap
    @StringKey(OutboxKinds.CART_MUTATION)
    abstract fun bindCartMutationOutboxHandler(impl: CartMutationOutboxHandler): OutboxKindHandler
}
