package com.equipseva.app.core.data.chat

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
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
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
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
class ChatRepository @Inject constructor(
    private val client: SupabaseClient,
) {

    // Fires after markConversationRead succeeds so observeConversations
    // can re-fetch and produce a fresh unreadCount=0. Without this, the
    // inbox badge would only clear on the next inbound-message refresh.
    // Replay 0 + extraBuffer 1 keeps it cheap; collectors that started
    // after the emit re-check via refresh() on next subscription.
    private val readEvents = MutableSharedFlow<String>(replay = 0, extraBufferCapacity = 1)

    // Singleton-lived scope for fire-and-forget realtime channel teardown.
    // Each observeXxx Flow registers a channel with the Supabase realtime
    // client; when the collector is cancelled, we need removeChannel() to
    // run even though the producing callbackFlow scope is itself winding
    // down. Launching the cleanup on a child of the callbackFlow scope
    // races against its cancellation and the channel can persist until
    // the next websocket reconnect. This scope outlives any individual
    // collector — its job survives the Singleton — so the cleanup
    // suspend always gets to start.
    private val cleanupScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    /** Emits the latest list of conversations the user participates in, ordered newest-first. */
    fun observeConversations(userId: String): Flow<List<ChatConversation>> = callbackFlow {
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
        val readJob = launch {
            readEvents.collect { reader -> if (reader == userId) refresh() }
        }
        channel.subscribe()

        awaitClose {
            job.cancel()
            readJob.cancel()
            cleanupScope.launch { client.realtime.removeChannel(channel) }
        }
    }.flowOn(Dispatchers.IO)

    /**
     * One-shot fetch of the conversations list for pull-to-refresh / manual reload.
     * Mirrors the same server query used by [observeConversations]. Safe to call while
     * the realtime channel is active — it does not interfere with the subscription.
     */
    suspend fun refreshConversations(userId: String): Result<List<ChatConversation>> = runCatching {
        fetchConversationsFor(userId)
    }

    /** Emits the message list for a conversation; re-emits on realtime inserts. */
    fun observeMessages(conversationId: String): Flow<List<ChatMessage>> = callbackFlow {
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
            cleanupScope.launch { client.realtime.removeChannel(channel) }
        }
    }.flowOn(Dispatchers.IO)

    /** Send a message; also patches the conversation's last_message/last_message_at. */
    suspend fun sendMessage(
        conversationId: String,
        senderUserId: String,
        message: String,
        attachments: List<String> = emptyList(),
    ): Result<ChatMessage> = runCatching {
        // Server CHECK (round286) caps chat_messages.message at 4000.
        // ChatViewModel already clamps the draft; mirror at the repo
        // boundary so outbox replays / scripts hit the same gate.
        val cappedMessage = message.take(4000)
        val dto = client.from(MESSAGES_TABLE).insert(
            MessageInsertDto(
                conversationId = conversationId,
                senderUserId = senderUserId,
                message = cappedMessage,
                attachments = attachments.ifEmpty { null },
            ),
        ) { select() }.decodeSingle<MessageDto>()

        runCatching {
            client.from(CONVERSATIONS_TABLE).update({
                set("last_message", cappedMessage)
                // Trust the server's `created_at`. Falling back to
                // client wall-clock (Instant.now()) bumped conversations
                // to wrong sort positions whenever device clock skewed —
                // skip the column if the server didn't echo a timestamp
                // and let the trigger/default handle ordering.
                dto.createdAt?.let { set("last_message_at", it) }
            }) {
                // Defense-in-depth: pair the conversation-id filter with a
                // participant check so a stolen/forged client write can't
                // touch the last_message preview on a conversation the
                // caller isn't actually in. RLS already gates this at the
                // server, but layering the participant_user_ids contains()
                // check means a column-grants regression wouldn't expose
                // arbitrary previews. Mirrors the read-side filter used in
                // fetchConversationsFor().
                filter {
                    eq("id", conversationId)
                    contains("participant_user_ids", listOf(senderUserId))
                }
            }
        }

        dto.toDomain()
    }

    /**
     * Returns an existing conversation linked to this repair job between the given participants,
     * or inserts a new one. Participants must contain exactly two user ids (buyer + engineer).
     */
    suspend fun getOrCreateForRepairJob(
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

    /**
     * Returns an existing direct (peer-to-peer) conversation between the two
     * participants, or inserts a new one with `related_entity_type='direct'`.
     * Used from the engineer public profile so a hospital can message an
     * engineer without first booking a job.
     */
    suspend fun getOrCreateDirect(
        selfUserId: String,
        peerUserId: String,
    ): Result<ChatConversation> = runCatching {
        require(selfUserId != peerUserId) { "Direct chat needs two distinct users" }

        // De-dupe: any existing 'direct' conversation that contains BOTH user
        // ids in its participant_user_ids array, regardless of insertion order.
        // Filter client-side after fetching the caller's direct conversations,
        // since Postgrest doesn't expose a clean array-contains-all match.
        // Filter server-side to rows that already include the caller so
        // RLS doesn't return tables of unrelated rows, and add a hard
        // upper bound so a power user with thousands of direct chats
        // doesn't pull the whole table into memory on each open-chat tap.
        val mine = client.from(CONVERSATIONS_TABLE).select {
            filter {
                eq("related_entity_type", "direct")
                contains("participant_user_ids", listOf(selfUserId))
            }
            limit(count = 500)
        }.decodeList<ConversationDto>()

        val match = mine.firstOrNull { dto ->
            matchesDirectParticipants(dto.participantUserIds, selfUserId, peerUserId)
        }

        val dto = match ?: client.from(CONVERSATIONS_TABLE).insert(
            ConversationInsertDto(
                participantUserIds = listOf(selfUserId, peerUserId),
                relatedEntityType = "direct",
                relatedEntityId = null,
            ),
        ) { select() }.decodeSingle<ConversationDto>()

        dto.toDomain()
    }

    /** Mark inbound messages (not authored by the reader) as read.
     *
     *  Also nudges the read-events SharedFlow so the conversations list
     *  re-fetches its unread counts. Without that nudge the realtime
     *  channel only refires on CONVERSATIONS_TABLE inserts/updates and
     *  a message-table read-receipt would leave the inbox badge stuck
     *  at the pre-open value until the next push arrived.
     */
    suspend fun markConversationRead(
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
        // emit (suspending) rather than tryEmit so a slow collector
        // can't silently drop the signal when extraBufferCapacity is
        // already at its single-slot limit.
        readEvents.emit(readerUserId)
        Unit
    }

    /** Fetch a conversation by id; null when not visible under RLS or missing. */
    suspend fun fetchById(conversationId: String): Result<ChatConversation?> = runCatching {
        client.from(CONVERSATIONS_TABLE).select {
            filter { eq("id", conversationId) }
            limit(count = 1)
        }.decodeList<ConversationDto>().firstOrNull()?.toDomain()
    }

    /**
     * Soft-delete a message the caller sent. Server-side the row is preserved but
     * the body is tombstoned and attachments cleared. Fails if the caller is not
     * the sender or the message was already deleted.
     */
    suspend fun deleteMessage(messageId: String): Result<Unit> = runCatching {
        // Ownership + "only deleted_at/message/attachments" guard live inside the
        // delete_my_chat_message RPC (SECURITY DEFINER). The function raises if
        // the row is not ours or is already tombstoned.
        client.postgrest.rpc(
            function = "delete_my_chat_message",
            parameters = buildJsonObject { put("p_message_id", JsonPrimitive(messageId)) },
        )
        Unit
    }

    /**
     * Re-derive the `last_message` / `last_message_at` preview on a conversation
     * row from the newest non-deleted message. Call after [deleteMessage] when
     * the deleted message may have been the most recent — otherwise the
     * Conversations list keeps showing the now-tombstoned text. Safe to call
     * on conversations with no remaining messages: clears the preview.
     */
    suspend fun recomputeConversationPreview(
        conversationId: String,
    ): Result<Unit> = runCatching {
        // Pick the newest non-tombstoned message and write its body /
        // created_at back onto the conversation row so the Conversations
        // list shows current preview text. RLS already gates this column
        // set (last_message + last_message_at only) for participants.
        val latest = client.from(MESSAGES_TABLE).select {
            filter {
                eq("conversation_id", conversationId)
                exact("deleted_at", null)
            }
            order("created_at", order = Order.DESCENDING)
            limit(count = 1)
        }.decodeList<MessageDto>().firstOrNull()

        // Defense-in-depth: pair the conversation-id filter with the
        // current user's participant check (mirrors sendMessage above).
        // If the caller isn't signed in, skip the write — recompute is
        // a best-effort preview cleanup and the next message will
        // refresh it. Without this, a column-grants regression would
        // let any signed-in caller clobber any conversation's preview.
        val callerUid = client.auth.currentUserOrNull()?.id ?: return@runCatching
        client.from(CONVERSATIONS_TABLE).update({
            set("last_message", latest?.message)
            set("last_message_at", latest?.createdAt)
        }) {
            filter {
                eq("id", conversationId)
                contains("participant_user_ids", listOf(callerUid))
            }
        }
        Unit
    }

    /**
     * Edit the body of a message the caller sent, within the 15-minute window enforced
     * by the server. Fails if the caller is not the sender, the message is deleted,
     * the window has elapsed, or the new body is empty / over 4000 chars.
     */
    suspend fun editMessage(messageId: String, newBody: String): Result<Unit> = runCatching {
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

    /**
     * Emits the set of other users currently typing in this conversation. Each emission
     * is the union of unique user ids whose last "typing" broadcast is within a short TTL
     * (~3s). State is purely client-side — nothing is persisted server-side — and the
     * caller's own id is filtered out.
     */
    fun observeTyping(
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
            cleanupScope.launch { client.realtime.removeChannel(channel) }
        }
    }.flowOn(Dispatchers.IO)

    /**
     * Fire-and-forget presence broadcast announcing the caller is typing. Debouncing is
     * the caller's responsibility — this is a pure send on the typing presence channel.
     */
    suspend fun broadcastTyping(conversationId: String, selfUserId: String) {
        // Caller is expected to throttle — we intentionally don't debounce here so the
        // repo stays stateless per call. Errors are swallowed: a missed typing frame is
        // not worth surfacing to the user. We also tear the channel back down once the
        // broadcast lands; otherwise every keystroke would leak a Realtime channel
        // until the websocket reconnect cleans them up.
        runCatching {
            val channel = client.channel("chat:typing:$conversationId")
            try {
                channel.subscribe()
                channel.broadcast(
                    event = TYPING_EVENT,
                    message = TypingPayload(userId = selfUserId, t = System.currentTimeMillis()),
                )
            } finally {
                runCatching { client.realtime.removeChannel(channel) }
            }
        }
    }

    @Serializable
    private data class TypingPayload(
        @kotlinx.serialization.SerialName("user_id") val userId: String,
        val t: Long,
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

/**
 * True when [participantUserIds] is exactly the pair `{self, peer}`.
 * Set-equality so the de-dupe matches regardless of insertion order in
 * the participant_user_ids array. A regression that compared lists
 * order-sensitively would let a duplicate "direct" conversation slip
 * past the de-dupe and surface two threads to the same pair.
 *
 * Null participant list is treated as no match (legacy conversation
 * row that pre-dates the column being non-null).
 */
internal fun matchesDirectParticipants(
    participantUserIds: List<String>?,
    selfUserId: String,
    peerUserId: String,
): Boolean = participantUserIds?.toSet() == setOf(selfUserId, peerUserId)
