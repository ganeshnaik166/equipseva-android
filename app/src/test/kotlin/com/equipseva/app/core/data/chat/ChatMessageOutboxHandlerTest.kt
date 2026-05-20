package com.equipseva.app.core.data.chat

import com.equipseva.app.core.sync.OutboxKindHandler
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pure-helper tests for [ChatMessageOutboxHandler]. The handler itself is
 * coupled to SupabaseClient.auth (currentUserOrNull), which we can't fake
 * without dragging in the SDK, so the load-bearing branch — the sender
 * owner-gate — is extracted into [senderGateDecision] and tested directly.
 *
 * Also pins the [ChatMessagePayload] wire shape: queued rows survive across
 * app restarts and a silent rename of one of these field names would make
 * every pending offline message GiveUp on drain (invisible data loss).
 */
class ChatMessageOutboxHandlerTest {

    private val json = Json { ignoreUnknownKeys = true }

    // --- senderGateDecision --------------------------------------------------

    @Test fun `no signed-in user yields Retry — outbox waits for next flush`() {
        // Outbox rows can outlive the auth session (background flush after a
        // sign-out / pre-sign-in). We retry rather than poison so a user who
        // signs back in still sees their queued message go out.
        val outcome = senderGateDecision(
            payloadSenderUserId = "uid-A",
            currentUid = null,
        )

        assertNotNull(outcome)
        assertTrue(outcome is OutboxKindHandler.Outcome.Retry)
    }

    @Test fun `mismatched sender yields GiveUp — different user is now signed in`() {
        // Shared device case: user A queued a chat, signed out, user B signed
        // in. We must NOT attempt the send under B — best case RLS rejects,
        // worst case a permissive RLS attributes A's message to B. Drop it.
        val outcome = senderGateDecision(
            payloadSenderUserId = "uid-A",
            currentUid = "uid-B",
        )

        assertNotNull(outcome)
        assertTrue(outcome is OutboxKindHandler.Outcome.GiveUp)
    }

    @Test fun `GiveUp reason names both ids for debuggability without leaking PII`() {
        // The poison-drop notification surfaces only the kind-level copy
        // (PoisonDropCopyTest covers that); this reason string is the
        // crash-log / breadcrumb. Both ids in the message make a sign-in
        // bug trivially diagnosable from a single log line.
        val outcome = senderGateDecision(
            payloadSenderUserId = "uid-A",
            currentUid = "uid-B",
        ) as OutboxKindHandler.Outcome.GiveUp

        assertTrue(outcome.reason.contains("uid-A"))
        assertTrue(outcome.reason.contains("uid-B"))
    }

    @Test fun `matching sender returns null — caller proceeds with the send`() {
        // The happy path: current auth user is exactly who queued the
        // message. null is the "no objection — proceed" signal.
        val outcome = senderGateDecision(
            payloadSenderUserId = "uid-A",
            currentUid = "uid-A",
        )

        assertNull(outcome)
    }

    @Test fun `empty-string sender is treated as a value — only null currentUid means no session`() {
        // Defensive: a future caller passing "" as a sender id is a mismatch
        // against a real signed-in user, not a missing session.
        val outcome = senderGateDecision(
            payloadSenderUserId = "",
            currentUid = "uid-A",
        )

        assertTrue(outcome is OutboxKindHandler.Outcome.GiveUp)
    }

    // --- ChatMessagePayload wire shape --------------------------------------

    @Test fun `payload round-trips through JSON preserving all fields`() {
        // Queued rows are persisted in the outbox table and decoded on a
        // later process. A silent rename of any field would make pending
        // messages fail to decode → GiveUp → invisible data loss.
        val original = ChatMessagePayload(
            conversationId = "conv-1",
            senderUserId = "uid-A",
            body = "hello world",
            attachments = listOf("path/a.jpg", "path/b.jpg"),
        )

        val encoded = json.encodeToString(ChatMessagePayload.serializer(), original)
        val decoded = json.decodeFromString(ChatMessagePayload.serializer(), encoded)

        assertEquals(original, decoded)
    }

    @Test fun `attachments default to empty list when omitted from JSON`() {
        // Older app versions queued rows without an attachments field; the
        // default keeps those rows decodable on the newer build.
        val partial = """{
            "conversationId":"conv-1",
            "senderUserId":"uid-A",
            "body":"hi"
        }""".trimIndent()

        val decoded = json.decodeFromString(ChatMessagePayload.serializer(), partial)

        assertEquals(emptyList<String>(), decoded.attachments)
    }

    @Test fun `malformed JSON fails to decode — handler maps this to GiveUp`() {
        // The handler wraps the decode in runCatching and returns GiveUp on
        // failure. We pin the decode-failure half here.
        val result = runCatching {
            json.decodeFromString(ChatMessagePayload.serializer(), "not-json")
        }
        assertTrue(result.isFailure)
    }

    @Test fun `missing senderUserId fails to decode — owner gate cannot default`() {
        // senderUserId is load-bearing for the owner gate; it must NOT
        // silently default to empty string.
        val partial = """{
            "conversationId":"conv-1",
            "body":"hi"
        }""".trimIndent()

        val result = runCatching {
            json.decodeFromString(ChatMessagePayload.serializer(), partial)
        }
        assertTrue(result.isFailure)
    }
}
