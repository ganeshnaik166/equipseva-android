package com.equipseva.app.core.data.notifications

import com.equipseva.app.core.sync.OutboxKindHandler
import com.equipseva.app.core.sync.OutboxKinds
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import dagger.multibindings.IntoMap
import dagger.multibindings.StringKey

@Module
@InstallIn(SingletonComponent::class)
abstract class NotificationModule {
    @Binds
    @IntoMap
    @StringKey(OutboxKinds.NOTIFICATION_READ)
    abstract fun bindNotificationReadOutboxHandler(
        impl: NotificationReadOutboxHandler,
    ): OutboxKindHandler
}
