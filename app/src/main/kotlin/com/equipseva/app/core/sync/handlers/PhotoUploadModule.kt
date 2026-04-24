package com.equipseva.app.core.sync.handlers

import com.equipseva.app.core.sync.OutboxKindHandler
import com.equipseva.app.core.sync.OutboxKinds
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import dagger.multibindings.IntoMap
import dagger.multibindings.StringKey
import javax.inject.Singleton

/**
 * Registers [PhotoUploadOutboxHandler] against [OutboxKinds.PHOTO_UPLOAD] in
 * the Dagger multibinding that [com.equipseva.app.core.sync.OutboxWorker]
 * consumes. Mirrors [com.equipseva.app.core.data.chat.ChatModule]'s wiring
 * for the chat message handler.
 */
@Module
@InstallIn(SingletonComponent::class)
abstract class PhotoUploadModule {
    @Binds
    @IntoMap
    @StringKey(OutboxKinds.PHOTO_UPLOAD)
    abstract fun bindPhotoUploadOutboxHandler(impl: PhotoUploadOutboxHandler): OutboxKindHandler

    @Binds
    @Singleton
    abstract fun bindPhotoUploadStash(impl: DefaultPhotoUploadStash): PhotoUploadStash
}
