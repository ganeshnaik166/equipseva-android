package com.equipseva.app.core.data.chat

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Order
import io.github.jan.supabase.postgrest.query.filter.FilterOperator
import io.github.jan.supabase.realtime.PostgresAction
import io.github.jan.supabase.realtime.channel
import io.github.jan.supabase.realtime.postgresChangeFlow
import io.github.jan.supabase.realtime.realtime
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.launch
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SupabaseChatRepository @Inject constructor(
    private val client: SupabaseClient,
) : ChatRepository {

    override fun observeConversations(userId: String): Flow<List<ChatConversation>> = callbackFlow {
        suspend fun refresh() {
            runCatching { fetchConversationsFor(userId) }.onSuccess { trySend(it) }
        }
        refresh()

        val channel = client.channel("chat:conv:$userId")
        val changes = channel.postgresChangeFlow<PostgresAction>(schema = "public") {
            table = CONVERSATIONS_TABLE
        }
        val job = launch {
            changes.collect { _ -> refresh() }
        }
        channel.subscribe()

        awaitClose {
            job.cancel()
            launch { client.realtime.removeChannel(channel) }
        }
    }.flowOn(Dispatchers.IO)

    override fun observeMessages(conversationId: String): Flow<List<ChatMessage>> = callbackFlow {
        suspend fun refresh() {
            runCatching { fetchMessagesFor(conversationId) }.onSuccess { trySend(it) }
        }
        refresh()

        val channel = client.channel("chat:msg:$conversationId")
        val changes = channel.postgresChangeFlow<PostgresAction>(schema = "public") {
            table = MESSAGES_TABLE
            filter("conversation_id", FilterOperator.EQ, conversationId)
        }
        val job = launch {
            changes.collect { _ -> refresh() }
        }
        channel.subscribe()

        awaitClose {
            job.cancel()
            launch { client.realtime.removeChannel(channel) }
        }
    }.flowOn(Dispatchers.IO)

    override suspend fun sendMessage(
        conversationId: String,
        senderUserId: String,
        message: String,
        attachments: List<String>,
    ): Result<ChatMessage> = runCatching {
        val dto = client.from(MESSAGES_TABLE).insert(
            MessageInsertDto(
                conversationId = conversationId,
                senderUserId = senderUserId,
                message = message,
                attachments = attachments.ifEmpty { null },
            ),
        ) { select() }.decodeSingle<MessageDto>()

        runCatching {
            client.from(CONVERSATIONS_TABLE).update({
                set("last_message", message)
                set("last_message_at", dto.createdAt ?: java.time.Instant.now().toString())
            }) {
                filter { eq("id", conversationId) }
            }
        }

        dto.toDomain()
    }

    override suspend fun getOrCreateForRepairJob(
        jobId: String,
        participantUserIds: List<String>,
    ): Result<ChatConversation> = runCatching {
        require(participantUserIds.size == 2) { "Repair chat needs exactly two participants" }

        val existing = client.from(CONVERSATIONS_TABLE).select {
            filter {
                eq("related_entity_type", "repair_job")
                eq("related_entity_id", jobId)
            }
            limit(count = 1)
        }.decodeList<ConversationDto>().firstOrNull()

        val dto = existing ?: client.from(CONVERSATIONS_TABLE).insert(
            ConversationInsertDto(
                participantUserIds = participantUserIds,
                relatedEntityType = "repair_job",
                relatedEntityId = jobId,
            ),
        ) { select() }.decodeSingle<ConversationDto>()

        dto.toDomain()
    }

    override suspend fun markConversationRead(
        conversationId: String,
        readerUserId: String,
    ): Result<Unit> = runCatching {
        client.from(MESSAGES_TABLE).update({
            set("is_read", true)
        }) {
            filter {
                eq("conversation_id", conversationId)
                neq("sender_user_id", readerUserId)
                eq("is_read", false)
            }
        }
        Unit
    }

    override suspend fun fetchById(conversationId: String): Result<ChatConversation?> = runCatching {
        client.from(CONVERSATIONS_TABLE).select {
            filter { eq("id", conversationId) }
            limit(count = 1)
        }.decodeList<ConversationDto>().firstOrNull()?.toDomain()
    }

    private suspend fun fetchConversationsFor(userId: String): List<ChatConversation> {
        // participant_user_ids is a uuid[]; use Postgrest "contains" to filter server-side.
        return client.from(CONVERSATIONS_TABLE).select {
            filter { contains("participant_user_ids", listOf(userId)) }
            order("last_message_at", order = Order.DESCENDING, nullsFirst = false)
            limit(count = 200)
        }.decodeList<ConversationDto>().map(ConversationDto::toDomain)
    }

    private suspend fun fetchMessagesFor(conversationId: String): List<ChatMessage> =
        client.from(MESSAGES_TABLE).select {
            filter { eq("conversation_id", conversationId) }
            order("created_at", order = Order.ASCENDING)
            limit(count = 500)
        }.decodeList<MessageDto>().map(MessageDto::toDomain)

    private companion object {
        const val CONVERSATIONS_TABLE = "chat_conversations"
        const val MESSAGES_TABLE = "chat_messages"
    }
}
