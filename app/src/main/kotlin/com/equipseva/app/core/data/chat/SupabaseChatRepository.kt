package com.equipseva.app.core.data.chat

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Order
import io.github.jan.supabase.postgrest.query.filter.FilterOperator
import io.github.jan.supabase.realtime.PostgresAction
import io.github.jan.supabase.realtime.broadcast
import io.github.jan.supabase.realtime.broadcastFlow
import io.github.jan.supabase.realtime.channel
import io.github.jan.supabase.realtime.postgresChangeFlow
import io.github.jan.supabase.realtime.realtime
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
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

    override fun observeTyping(
        conversationId: String,
        selfUserId: String,
    ): Flow<Set<String>> = callbackFlow {
        // Separate channel from the messages sub so realtime payloads can't cross-talk.
        val channel = client.channel("chat:typing:$conversationId")
        val events = channel.broadcastFlow<TypingPayload>(event = TYPING_EVENT)

        // Last-seen timestamp (epoch ms) per userId. A user counts as "typing" while
        // we've heard from them within TYPING_TTL_MS. Everything client-side: the
        // server never knows about typing state.
        val lastSeen = mutableMapOf<String, Long>()
        var emitted: Set<String> = emptySet()

        fun recompute(): Set<String> {
            val now = System.currentTimeMillis()
            val iter = lastSeen.entries.iterator()
            while (iter.hasNext()) {
                val (_, ts) = iter.next()
                if (now - ts > TYPING_TTL_MS) iter.remove()
            }
            return lastSeen.keys.toSet()
        }

        fun maybeEmit() {
            val next = recompute()
            if (next != emitted) {
                emitted = next
                trySend(next)
            }
        }

        // Prime with empty so consumers don't have to handle the null-before-first-event case.
        trySend(emptySet())

        val recvJob = launch {
            events.collect { payload ->
                if (payload.userId != selfUserId) {
                    lastSeen[payload.userId] = System.currentTimeMillis()
                    maybeEmit()
                }
            }
        }

        // TTL sweep — re-emit an empty set once last typist falls out of the window.
        val tickJob = launch {
            while (true) {
                delay(TYPING_TICK_MS)
                if (lastSeen.isNotEmpty()) maybeEmit()
            }
        }

        channel.subscribe()

        awaitClose {
            recvJob.cancel()
            tickJob.cancel()
            launch { client.realtime.removeChannel(channel) }
        }
    }.flowOn(Dispatchers.IO)

    override suspend fun broadcastTyping(conversationId: String, selfUserId: String) {
        // Caller is expected to throttle — we intentionally don't debounce here so the
        // repo stays stateless per call. Errors are swallowed: a missed typing frame is
        // not worth surfacing to the user.
        runCatching {
            val channel = client.channel("chat:typing:$conversationId")
            channel.subscribe()
            channel.broadcast(
                event = TYPING_EVENT,
                message = TypingPayload(userId = selfUserId, t = System.currentTimeMillis()),
            )
        }
    }

    @Serializable
    internal data class TypingPayload(
        @kotlinx.serialization.SerialName("user_id") val userId: String,
        @kotlinx.serialization.SerialName("t") val t: Long,
    )

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
        const val TYPING_EVENT = "typing"
        // A typist is considered "active" while the last frame from them is within this
        // window. Tick cadence is separate so the set re-emits empty promptly on fall-off.
        const val TYPING_TTL_MS = 3_000L
        const val TYPING_TICK_MS = 1_000L
    }
}
