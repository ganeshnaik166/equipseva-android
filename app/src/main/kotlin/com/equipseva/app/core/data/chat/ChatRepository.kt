package com.equipseva.app.core.data.chat

import kotlinx.coroutines.flow.Flow

interface ChatRepository {
    /** Emits the latest list of conversations the user participates in, ordered newest-first. */
    fun observeConversations(userId: String): Flow<List<ChatConversation>>

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

    /** Mark inbound messages (not authored by the reader) as read. */
    suspend fun markConversationRead(conversationId: String, readerUserId: String): Result<Unit>

    /** Fetch a conversation by id; null when not visible under RLS or missing. */
    suspend fun fetchById(conversationId: String): Result<ChatConversation?>
}
