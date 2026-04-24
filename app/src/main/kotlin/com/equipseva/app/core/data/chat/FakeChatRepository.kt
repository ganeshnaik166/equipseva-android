package com.equipseva.app.core.data.chat

import com.equipseva.app.core.data.demo.DemoSeed
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import javax.inject.Inject
import javax.inject.Singleton

/**
 * In-memory implementation backed by [DemoSeed]. Wired in by [ChatModule] when
 * `BuildConfig.DEMO_MODE` is true so the inbox + thread screens render seeded
 * conversations. Sends + read-marks are no-ops.
 */
@Singleton
class FakeChatRepository @Inject constructor() : ChatRepository {

    override fun observeConversations(userId: String): Flow<List<ChatConversation>> {
        val list = DemoSeed.chatConversations
            .filter { userId in it.participantUserIds }
            .sortedByDescending { it.lastMessageInstant }
        return flowOf(list)
    }

    override fun observeMessages(conversationId: String): Flow<List<ChatMessage>> {
        val list = DemoSeed.chatMessages
            .filter { it.conversationId == conversationId }
            .sortedBy { it.createdAtInstant }
        return flowOf(list)
    }

    override suspend fun sendMessage(
        conversationId: String,
        senderUserId: String,
        message: String,
        attachments: List<String>,
    ): Result<ChatMessage> =
        Result.failure(UnsupportedOperationException("Demo mode: chat send is disabled"))

    override suspend fun getOrCreateForRepairJob(
        jobId: String,
        participantUserIds: List<String>,
    ): Result<ChatConversation> {
        val existing = DemoSeed.chatConversations
            .firstOrNull { it.relatedEntityType == "repair_job" && it.relatedEntityId == jobId }
        return existing
            ?.let { Result.success(it) }
            ?: Result.failure(UnsupportedOperationException("Demo mode: cannot create new conversation"))
    }

    override suspend fun getOrCreateForRfqBid(
        bidId: String,
        participantUserIds: List<String>,
    ): Result<ChatConversation> {
        val existing = DemoSeed.chatConversations
            .firstOrNull { it.relatedEntityType == "rfq_bid" && it.relatedEntityId == bidId }
        return existing
            ?.let { Result.success(it) }
            ?: Result.failure(UnsupportedOperationException("Demo mode: cannot create new conversation"))
    }

    override suspend fun markConversationRead(conversationId: String, readerUserId: String): Result<Unit> =
        // No-op success so screens that fire-and-forget on open don't error.
        Result.success(Unit)

    override suspend fun fetchById(conversationId: String): Result<ChatConversation?> =
        Result.success(DemoSeed.chatConversations.firstOrNull { it.id == conversationId })
}
