package com.equipseva.app.core.sync

import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.entities.OutboxEntryEntity
import com.equipseva.app.core.data.notifications.NotificationReadOutboxHandler
import com.equipseva.app.core.data.notifications.NotificationReadPayload
import com.equipseva.app.core.data.notifications.NotificationRepository
import com.equipseva.app.testing.FakeAuthRepository
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The mark-read drain must defer while there is no signed-in user, the way
 * every other outbox handler does.
 *
 * This handler resolves the user from the session flow, and at WorkManager
 * cold start that flow is still `Unknown` (the persisted session is being
 * restored) while a transient refresh failure reads as `SignedOut`. Handing
 * that null user to the cross-account gate made it report a cross-user drop,
 * so the row was deleted as though the account had been switched — the
 * notification then bounced back to unread on the next sync, over and over,
 * with nothing in the queue left to fix it.
 *
 * The four sibling handlers (chat, bid, job status, photo) all defer in the
 * same state; this asymmetry was a defect, not the documented strict/lenient
 * split, which is about what a NULL *queued owner* means.
 */
class NotificationReadDrainSessionTest {

    private val json = Json { ignoreUnknownKeys = true }
    private val owner = "11111111-1111-4111-8111-111111111111"
    private val someoneElse = "22222222-2222-4222-8222-222222222222"

    private fun handlerFor(session: AuthSession, repository: NotificationRepository) =
        NotificationReadOutboxHandler(repository, FakeAuthRepository(session), json)

    private fun repository(): NotificationRepository = mockk<NotificationRepository>().also {
        coEvery { it.markRead(any()) } returns Result.success(Unit)
    }

    private fun entry(userId: String?): OutboxEntryEntity = OutboxEntryEntity(
        kind = OutboxKinds.NOTIFICATION_READ,
        payload = json.encodeToString(
            NotificationReadPayload.serializer(),
            NotificationReadPayload(notificationId = "n-1", userId = userId),
        ),
        createdAt = 1_700_000_000_000L,
    )

    @Test fun `a session still restoring defers the row instead of dropping it`() = runTest {
        val repository = repository()
        val outcome = handlerFor(AuthSession.Unknown, repository).handle(entry(owner))

        assertTrue("got $outcome", outcome is OutboxKindHandler.Outcome.Retry)
        coVerify(exactly = 0) { repository.markRead(any()) }
    }

    @Test fun `a restoring session does not spend one of the entry's attempts`() = runTest {
        // Five ticks of this used to be enough to empty the queue: the budget
        // exists to cap genuine failures, and no write was attempted here.
        val outcome = handlerFor(AuthSession.Unknown, repository()).handle(entry(owner))

        val retry = outcome as OutboxKindHandler.Outcome.Retry
        assertFalse("a precondition must not charge an attempt", retry.countsAgainstBudget)
    }

    @Test fun `a transient refresh failure reading as signed out also defers`() = runTest {
        val outcome = handlerFor(AuthSession.SignedOut, repository()).handle(entry(owner))

        assertTrue("got $outcome", outcome is OutboxKindHandler.Outcome.Retry)
    }

    @Test fun `a legacy row with no queued owner also waits for a session`() = runTest {
        // Rows queued before the owner field existed fall through to RLS, but
        // "fall through to RLS" still needs a token to send.
        val repository = repository()
        val outcome = handlerFor(AuthSession.Unknown, repository).handle(entry(userId = null))

        assertTrue("got $outcome", outcome is OutboxKindHandler.Outcome.Retry)
        coVerify(exactly = 0) { repository.markRead(any()) }
    }

    @Test fun `an actual account switch is still dropped`() = runTest {
        // The gate's real job. A different user signed in means RLS would
        // reject the row anyway, so it must not sit in the queue burning
        // attempts — this is the case the Retry above must not swallow.
        val repository = repository()
        val session = AuthSession.SignedIn(userId = someoneElse, email = null)
        val outcome = handlerFor(session, repository).handle(entry(owner))

        assertTrue("got $outcome", outcome is OutboxKindHandler.Outcome.GiveUp)
        val reason = (outcome as OutboxKindHandler.Outcome.GiveUp).reason
        assertTrue("reason should name both accounts: $reason", reason.contains(owner) && reason.contains(someoneElse))
        coVerify(exactly = 0) { repository.markRead(any()) }
    }

    @Test fun `the owner's own row drains`() = runTest {
        val repository = repository()
        val session = AuthSession.SignedIn(userId = owner, email = null)
        val outcome = handlerFor(session, repository).handle(entry(owner))

        assertEquals(OutboxKindHandler.Outcome.Success, outcome)
        coVerify(exactly = 1) { repository.markRead("n-1") }
    }

    @Test fun `a legacy row drains for whoever is signed in`() = runTest {
        // The documented LENIENT policy for this kind: a null queued owner is
        // not a cross-user case, it is an old row with no owner recorded.
        val repository = repository()
        val session = AuthSession.SignedIn(userId = owner, email = null)
        val outcome = handlerFor(session, repository).handle(entry(userId = null))

        assertEquals(OutboxKindHandler.Outcome.Success, outcome)
        coVerify(exactly = 1) { repository.markRead("n-1") }
    }
}
