package com.equipseva.app.core.sync

import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent

/**
 * Registry for [OutboxKindHandler]s. Feature modules contribute their own
 * handlers by adding another provider method to this module (or by creating
 * a sibling module that merges the same map).
 *
 * This starter module intentionally provides an empty map — unknown kinds are
 * routed to "give up" by the worker so a stale entry can't livelock the queue.
 * Wire real handlers as each feature's offline support lands.
 */
@Module
@InstallIn(SingletonComponent::class)
object OutboxHandlersModule {

    @Provides
    fun provideHandlers(): Map<String, @JvmSuppressWildcards OutboxKindHandler> = emptyMap()
}
