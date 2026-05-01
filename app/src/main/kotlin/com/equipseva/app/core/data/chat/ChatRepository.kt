package com.equipseva.app.core.data.chat

import kotlinx.coroutines.flow.Flow

interface ChatRepository {
    /** Emits the latest list of conversations the user participates in, ordered newest-first. */
    fun observeConversations(userId: String): Flow<List<ChatConversation>>

    /**
     * One-shot fetch of the conversations list for pull-to-refresh / manual reload.
     * Mirrors the same server query used by [observeConversations]. Safe to call while
     * the realtime channel is active — it does not interfere with the subscription.
     */
    suspend fun refreshConversations(userId: String): Result<List<ChatConversation>>

    /** Emits the message list for a conversation; re-emits on realtime inserts. */
    fun observeMessages(conversationId: String): Flow<List<ChatMessage>>

    /** Send a message; repository also patches the conversation's last_message/last_message_at. */
    suspend fun sendMessage(
        conversationId: String,
        senderUserId: String,
        message: String,
        attachments: List<String> = emptyList(),
    ): Result<ChatMessage>

    /**
     * Returns an existing conversation linked to this repair job between the given participants,
     * or inserts a new one. Participants must contain exactly two user ids (buyer + engineer).
     */
    suspend fun getOrCreateForRepairJob(
        jobId: String,
        participantUserIds: List<String>,
    ): Result<ChatConversation>

    /**
     * Returns an existing conversation linked to this RFQ bid between the given participants,
     * or inserts a new one. Participants must contain exactly two user ids (hospital + supplier).
     */
    suspend fun getOrCreateForRfqBid(
        bidId: String,
        participantUserIds: List<String>,
    ): Result<ChatConversation>

    /**
     * Returns an existing direct (peer-to-peer) conversation between the two
     * participants, or inserts a new one with `related_entity_type='direct'`.
     * Used from the engineer public profile so a hospital can message an
     * engineer without first booking a job.
     */
    suspend fun getOrCreateDirect(
        selfUserId: String,
        peerUserId: String,
    ): Result<ChatConversation>

    /** Mark inbound messages (not authored by the reader) as read. */
    suspend fun markConversationRead(conversationId: String, readerUserId: String): Result<Unit>

    /** Fetch a conversation by id; null when not visible under RLS or missing. */
    suspend fun fetchById(conversationId: String): Result<ChatConversation?>

    /**
     * Soft-delete a message the caller sent. Server-side the row is preserved but
     * the body is tombstoned and attachments cleared. Fails if the caller is not
     * the sender or the message was already deleted.
     */
    suspend fun deleteMessage(messageId: String): Result<Unit>

    /**
     * Edit the body of a message the caller sent, within the 15-minute window enforced
     * by the server. Fails if the caller is not the sender, the message is deleted,
     * the window has elapsed, or the new body is empty / over 4000 chars.
     */
    suspend fun editMessage(messageId: String, newBody: String): Result<Unit>

    /**
     * Emits the set of other users currently typing in this conversation. Each emission
     * is the union of unique user ids whose last "typing" broadcast is within a short TTL
     * (~3s). State is purely client-side — nothing is persisted server-side — and the
     * caller's own id is filtered out.
     */
    fun observeTyping(conversationId: String, selfUserId: String): kotlinx.coroutines.flow.Flow<Set<String>>

    /**
     * Fire-and-forget presence broadcast announcing the caller is typing. Debouncing is
     * the caller's responsibility — this is a pure send on the typing presence channel.
     */
    suspend fun broadcastTyping(conversationId: String, selfUserId: String)
}
