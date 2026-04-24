package com.equipseva.app.core.data.chat

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
abstract class ChatModule {
    @Binds
    @Singleton
    abstract fun bindChatRepository(impl: SupabaseChatRepository): ChatRepository

    @Binds
    @IntoMap
    @StringKey(OutboxKinds.CHAT_MESSAGE)
    abstract fun bindChatMessageOutboxHandler(impl: ChatMessageOutboxHandler): OutboxKindHandler
}
