package com.equipseva.app.core.data.chat

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
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
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
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

    override suspend fun refreshConversations(userId: String): Result<List<ChatConversation>> = runCatching {
        fetchConversationsFor(userId)
    }

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

    override suspend fun getOrCreateForRfqBid(
        bidId: String,
        participantUserIds: List<String>,
    ): Result<ChatConversation> = runCatching {
        require(participantUserIds.size == 2) { "RFQ bid chat needs exactly two participants" }

        val existing = client.from(CONVERSATIONS_TABLE).select {
            filter {
                eq("related_entity_type", "rfq_bid")
                eq("related_entity_id", bidId)
            }
            limit(count = 1)
        }.decodeList<ConversationDto>().firstOrNull()

        val dto = existing ?: client.from(CONVERSATIONS_TABLE).insert(
            ConversationInsertDto(
                participantUserIds = participantUserIds,
                relatedEntityType = "rfq_bid",
                relatedEntityId = bidId,
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

    override suspend fun deleteMessage(messageId: String): Result<Unit> = runCatching {
        // Ownership + "only deleted_at/message/attachments" guard live inside the
        // delete_my_chat_message RPC (SECURITY DEFINER). The function raises if
        // the row is not ours or is already tombstoned.
        client.postgrest.rpc(
            function = "delete_my_chat_message",
            parameters = buildJsonObject { put("p_message_id", JsonPrimitive(messageId)) },
        )
        Unit
    }

    override suspend fun editMessage(messageId: String, newBody: String): Result<Unit> = runCatching {
        // Ownership, column set (message + edited_at only), body length 1..4000, and
        // the 15-minute window are all enforced by edit_my_chat_message (SECURITY
        // DEFINER). Server is authoritative; we don't recheck the time on the client.
        client.postgrest.rpc(
            function = "edit_my_chat_message",
            parameters = buildJsonObject {
                put("p_message_id", JsonPrimitive(messageId))
                put("p_new_body", JsonPrimitive(newBody))
            },
        )
        Unit
    }

    private suspend fun fetchConversationsFor(userId: String): List<ChatConversation> {
        // participant_user_ids is a uuid[]; use Postgrest "contains" to filter server-side.
        val conversations = client.from(CONVERSATIONS_TABLE).select {
            filter { contains("participant_user_ids", listOf(userId)) }
            order("last_message_at", order = Order.DESCENDING, nullsFirst = false)
            limit(count = 200)
        }.decodeList<ConversationDto>().map(ConversationDto::toDomain)

        if (conversations.isEmpty()) return conversations

        val unreadByConversation = runCatching {
            client.from(MESSAGES_TABLE).select(columns = io.github.jan.supabase.postgrest.query.Columns.list("conversation_id")) {
                filter {
                    isIn("conversation_id", conversations.map { it.id })
                    neq("sender_user_id", userId)
                    eq("is_read", false)
                }
                limit(count = 2000)
            }.decodeList<UnreadRowDto>()
                .groupingBy { it.conversationId }
                .eachCount()
        }.getOrDefault(emptyMap())

        return conversations.map { convo ->
            val count = unreadByConversation[convo.id] ?: 0
            if (count > 0) convo.copy(unreadCount = count) else convo
        }
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
