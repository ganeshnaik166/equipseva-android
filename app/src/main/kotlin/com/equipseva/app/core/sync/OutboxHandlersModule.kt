package com.equipseva.app.core.sync

import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import dagger.multibindings.Multibinds

/**
 * Registry for [OutboxKindHandler]s. Feature modules contribute their own
 * handlers via @IntoMap + @StringKey(<one of [OutboxKinds]>) bindings into
 * the same [Map] declared here.
 *
 * Entries whose `kind` has no registered handler are dropped by the worker
 * so a stale entry from an older build can't livelock the queue.
 */
@Module
@InstallIn(SingletonComponent::class)
abstract class OutboxHandlersModule {

    @Multibinds
    abstract fun handlers(): Map<String, @JvmSuppressWildcards OutboxKindHandler>
}
