package com.equipseva.app.core.data.chat

import com.equipseva.app.BuildConfig
import com.equipseva.app.core.sync.OutboxKindHandler
import com.equipseva.app.core.sync.OutboxKinds
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import dagger.multibindings.IntoMap
import dagger.multibindings.StringKey
import javax.inject.Provider
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object ChatModule {

    @Provides
    @Singleton
    fun provideChatRepository(
        supabase: Provider<SupabaseChatRepository>,
        fake: Provider<FakeChatRepository>,
    ): ChatRepository =
        if (BuildConfig.DEMO_MODE) fake.get() else supabase.get()

    @Provides
    @IntoMap
    @StringKey(OutboxKinds.CHAT_MESSAGE)
    fun provideChatMessageOutboxHandler(impl: ChatMessageOutboxHandler): OutboxKindHandler = impl
}
