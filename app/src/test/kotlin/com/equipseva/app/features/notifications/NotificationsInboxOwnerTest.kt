package com.equipseva.app.features.notifications

import androidx.lifecycle.ViewModelStore
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.notifications.Notification
import com.equipseva.app.core.data.notifications.NotificationReadPayload
import com.equipseva.app.core.data.notifications.NotificationRepository
import com.equipseva.app.core.sync.OutboxEnqueuer
import com.equipseva.app.core.sync.OutboxKinds
import com.equipseva.app.testing.FakeAuthRepository
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlinx.serialization.json.Json
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.IOException
import java.time.Instant
import kotlin.coroutines.Continuation
import kotlin.coroutines.resume
import kotlin.coroutines.suspendCoroutine

/**
 * Security regressions for a retained inbox ViewModel on a shared device.
 * These deliberately exercise observed AuthSession boundaries, without an
 * Android navigation graph or a real Supabase account. A separate A3 owner
 * gate is still required at the final deep-link navigation boundary.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class NotificationsInboxOwnerTest {
    private val accountA = "account-a"
    private val accountB = "account-b"

    private lateinit var auth: FakeAuthRepository
    private lateinit var repository: NotificationRepository
    private lateinit var outbox: OutboxEnqueuer
    private lateinit var viewModel: NotificationsInboxViewModel
    private lateinit var viewModelStore: ViewModelStore

    private val streams = mutableMapOf<String, MutableSharedFlow<List<Notification>>>()
    private val observeCalls = mutableListOf<String>()
    private val refreshCalls = mutableListOf<String>()
    private val markReadCalls = mutableListOf<String>()
    private val markAllCalls = mutableListOf<String>()

    private var refreshAnswer: suspend (String) -> Result<List<Notification>> = {
        Result.success(emptyList())
    }
    private var markReadAnswer: suspend (String) -> Result<Unit> = { Result.success(Unit) }
    private var markAllAnswer: suspend (String) -> Result<Unit> = { Result.success(Unit) }

    @Before fun setUp() {
        Dispatchers.setMain(StandardTestDispatcher())
        auth = FakeAuthRepository()
        repository = mockk()
        outbox = mockk(relaxed = true)
        viewModelStore = ViewModelStore()

        every { repository.observeNotifications(any()) } answers {
            val userId = firstArg<String>()
            observeCalls += userId
            streams.getOrPut(userId) { MutableSharedFlow(extraBufferCapacity = 2) }
        }
        coEvery { repository.refreshNotifications(any()) } coAnswers {
            val userId = firstArg<String>()
            refreshCalls += userId
            refreshAnswer(userId)
        }
        coEvery { repository.markRead(any()) } coAnswers {
            val id = firstArg<String>()
            markReadCalls += id
            markReadAnswer(id)
        }
        coEvery { repository.markAllRead(any()) } coAnswers {
            val userId = firstArg<String>()
            markAllCalls += userId
            markAllAnswer(userId)
        }

        viewModel = NotificationsInboxViewModel(auth, repository, outbox, Json)
        viewModelStore.put("inbox", viewModel)
    }

    @After fun tearDown() {
        viewModelStore.clear()
        Dispatchers.resetMain()
    }

    @Test fun `direct account replacement clears old rows and queries the new owner`() = runTest {
        signIn(accountA)
        showRows(accountA, row("a-row"))
        assertEquals(listOf("a-row"), viewModel.state.value.rows.map { it.id })

        signIn(accountB)

        assertTrue("A rows must disappear before B's fetch completes", viewModel.state.value.rows.isEmpty())
        assertEquals(0, viewModel.state.value.unreadCount)
        assertEquals(listOf(accountA, accountB), observeCalls)
        assertEquals(0, streams.getValue(accountA).subscriptionCount.value)
        viewModel.refresh()
        runCurrent()
        assertEquals(listOf(accountB), refreshCalls)
        viewModel.markRead("a-row")
        viewModel.markAllRead()
        runCurrent()
        assertTrue("A row cannot be marked under B", markReadCalls.isEmpty())
        assertTrue("A inbox cannot be bulk-marked under B", markAllCalls.isEmpty())
    }

    @Test fun `sign-out clears rows and disables all inbox actions`() = runTest {
        signIn(accountA)
        showRows(accountA, row("a-row"))

        auth.setSession(AuthSession.SignedOut)
        runCurrent()

        assertTrue(viewModel.state.value.rows.isEmpty())
        assertFalse(viewModel.state.value.hasUnread)
        assertEquals(0, streams.getValue(accountA).subscriptionCount.value)
        viewModel.refresh()
        viewModel.markRead("a-row")
        viewModel.markAllRead()
        runCurrent()
        assertTrue(refreshCalls.isEmpty())
        assertTrue(markReadCalls.isEmpty())
        assertTrue(markAllCalls.isEmpty())
    }

    @Test fun `Unknown clears rows and cannot retain an active owner`() = runTest {
        signIn(accountA)
        showRows(accountA, row("a-row"))

        auth.setSession(AuthSession.Unknown)
        runCurrent()

        assertTrue(viewModel.state.value.rows.isEmpty())
        assertFalse(viewModel.state.value.hasUnread)
        assertEquals(0, streams.getValue(accountA).subscriptionCount.value)
        viewModel.refresh()
        runCurrent()
        assertTrue(refreshCalls.isEmpty())
    }

    @Test fun `blank signed-in ids fail closed and never start a blank query`() = runTest {
        signIn(accountA)
        showRows(accountA, row("a-row"))

        signIn("   ")

        assertTrue(viewModel.state.value.rows.isEmpty())
        assertEquals(listOf(accountA), observeCalls)
        viewModel.refresh()
        runCurrent()
        assertTrue(refreshCalls.isEmpty())
    }

    @Test fun `observed A to B to A requires a new A subscription and fresh rows`() = runTest {
        signIn(accountA)
        showRows(accountA, row("old-a"))
        signIn(accountB)
        showRows(accountB, row("b-row"))

        signIn(accountA)

        assertTrue("old A and B rows must both be gone", viewModel.state.value.rows.isEmpty())
        assertEquals(listOf(accountA, accountB, accountA), observeCalls)
        showRows(accountA, row("fresh-a"))
        assertEquals(listOf("fresh-a"), viewModel.state.value.rows.map { it.id })
    }

    @Test fun `same account sign-out and sign-in refetches instead of restoring cached rows`() = runTest {
        signIn(accountA)
        showRows(accountA, row("old-a"))
        auth.setSession(AuthSession.SignedOut)
        runCurrent()

        signIn(accountA)

        assertTrue(viewModel.state.value.rows.isEmpty())
        assertEquals(listOf(accountA, accountA), observeCalls)
        showRows(accountA, row("fresh-a"))
        assertEquals(listOf("fresh-a"), viewModel.state.value.rows.map { it.id })
    }

    @Test fun `duplicate and email-only events for the same id preserve one subscription`() = runTest {
        signIn(accountA, "old@example.test")
        showRows(accountA, row("a-row"))

        signIn(accountA, "new@example.test")
        signIn(accountA, "new@example.test")

        assertEquals(listOf(accountA), observeCalls)
        assertEquals(listOf("a-row"), viewModel.state.value.rows.map { it.id })
        assertEquals(1, streams.getValue(accountA).subscriptionCount.value)
    }

    @Test fun `late noncooperative A refresh cannot publish an error into B`() = runTest {
        val lateA = NonCooperativeReply<Result<List<Notification>>>()
        refreshAnswer = { userId ->
            if (userId == accountA) lateA.await() else Result.success(emptyList())
        }
        signIn(accountA)
        showRows(accountA, row("a-row"))
        viewModel.refresh()
        runCurrent()
        assertTrue(viewModel.state.value.refreshing)

        signIn(accountB)
        showRows(accountB, row("b-row"))
        lateA.complete(Result.failure(IOException("old account is offline")))
        runCurrent()

        assertEquals(listOf("b-row"), viewModel.state.value.rows.map { it.id })
        assertNull("A's failure must not appear in B's inbox", viewModel.state.value.errorMessage)
        assertFalse(viewModel.state.value.refreshing)
        viewModel.refresh()
        runCurrent()
        assertEquals(listOf(accountA, accountB), refreshCalls)
    }

    @Test fun `late noncooperative A mark-read failure cannot enqueue under B`() = runTest {
        val lateA = NonCooperativeReply<Result<Unit>>()
        markReadAnswer = { id ->
            if (id == "a-row") lateA.await() else Result.success(Unit)
        }
        signIn(accountA)
        showRows(accountA, row("a-row"))
        viewModel.markRead("a-row")
        runCurrent()
        assertEquals(listOf("a-row"), markReadCalls)

        signIn(accountB)
        showRows(accountB, row("b-row"))
        lateA.complete(Result.failure(IOException("old account is offline")))
        runCurrent()

        coVerify(exactly = 0) { outbox.enqueue(any(), any()) }
        assertEquals(listOf("b-row"), viewModel.state.value.rows.map { it.id })
        viewModel.markRead("b-row")
        runCurrent()
        assertEquals(listOf("a-row", "b-row"), markReadCalls)
    }

    @Test fun `late read from old A login cannot enqueue after observed A to B to A`() = runTest {
        val lateA = NonCooperativeReply<Result<Unit>>()
        markReadAnswer = { id ->
            if (id == "old-a") lateA.await() else Result.success(Unit)
        }
        signIn(accountA)
        showRows(accountA, row("old-a"))
        viewModel.markRead("old-a")
        runCurrent()

        signIn(accountB)
        showRows(accountB, row("b-row"))
        signIn(accountA)
        showRows(accountA, row("fresh-a"))
        lateA.complete(Result.failure(IOException("old A request failed")))
        runCurrent()

        coVerify(exactly = 0) { outbox.enqueue(any(), any()) }
        assertEquals(listOf("fresh-a"), viewModel.state.value.rows.map { it.id })
        assertTrue(viewModel.state.value.rows.single().isUnread)
    }

    @Test fun `late noncooperative A mark-all success cannot mark B rows read`() = runTest {
        val lateA = NonCooperativeReply<Result<Unit>>()
        markAllAnswer = { userId ->
            if (userId == accountA) lateA.await() else Result.success(Unit)
        }
        signIn(accountA)
        showRows(accountA, row("a-row"))
        viewModel.markAllRead()
        runCurrent()
        assertEquals(listOf(accountA), markAllCalls)

        signIn(accountB)
        showRows(accountB, row("b-row"))
        lateA.complete(Result.success(Unit))
        runCurrent()

        assertEquals(listOf("b-row"), viewModel.state.value.rows.map { it.id })
        assertTrue("B's unread row must remain unread", viewModel.state.value.rows.single().isUnread)
        assertEquals(1, viewModel.state.value.unreadCount)
    }

    @Test fun `late noncooperative A mark-all failure cannot show an error in B`() = runTest {
        val lateA = NonCooperativeReply<Result<Unit>>()
        markAllAnswer = { userId ->
            if (userId == accountA) lateA.await() else Result.success(Unit)
        }
        signIn(accountA)
        showRows(accountA, row("a-row"))
        viewModel.markAllRead()
        runCurrent()

        signIn(accountB)
        showRows(accountB, row("b-row"))
        lateA.complete(Result.failure(IOException("old account is offline")))
        runCurrent()

        assertEquals(listOf("b-row"), viewModel.state.value.rows.map { it.id })
        assertNull("A's failure must not appear in B's inbox", viewModel.state.value.errorMessage)
    }

    @Test fun `fresh B refresh and read operations still work after replacement`() = runTest {
        refreshAnswer = { userId ->
            if (userId == accountB) Result.success(listOf(row("b-one"), row("b-two")))
            else Result.success(emptyList())
        }
        signIn(accountA)
        showRows(accountA, row("a-row"))
        signIn(accountB)
        showRows(accountB, row("b-one"), row("b-two"))

        viewModel.refresh()
        runCurrent()
        assertEquals(listOf("b-one", "b-two"), viewModel.state.value.rows.map { it.id })
        viewModel.markRead("b-one")
        runCurrent()
        assertEquals(listOf(accountB), refreshCalls)
        assertEquals(listOf("b-one"), markReadCalls)
        assertEquals(1, viewModel.state.value.unreadCount)

        viewModel.markAllRead()
        runCurrent()
        assertEquals(listOf(accountB), markAllCalls)
        assertEquals(0, viewModel.state.value.unreadCount)
    }

    @Test fun `stale rendered row and bulk callbacks cannot act on a reused id in B`() = runTest {
        signIn(accountA)
        showRows(accountA, row("shared-id"))
        val aGeneration = viewModel.state.value.ownerGeneration

        signIn(accountB)
        showRows(accountB, row("shared-id"))

        assertNull(viewModel.rowForOpen("shared-id", aGeneration))
        viewModel.markRead("shared-id", aGeneration)
        viewModel.markAllRead(aGeneration)
        runCurrent()
        assertTrue(markReadCalls.isEmpty())
        assertTrue(markAllCalls.isEmpty())
        assertTrue(viewModel.state.value.rows.single().isUnread)
        assertEquals("shared-id", viewModel.rowForOpen(
            "shared-id", viewModel.state.value.ownerGeneration,
        )?.id)
    }

    @Test fun `late same-owner refresh cannot overwrite a newer stream emission`() = runTest {
        val delayed = NonCooperativeReply<Result<List<Notification>>>()
        refreshAnswer = { delayed.await() }
        signIn(accountA)
        showRows(accountA, row("old"))
        viewModel.refresh()
        runCurrent()

        showRows(accountA, row("new"))
        delayed.complete(Result.success(listOf(row("old"))))
        runCurrent()

        assertEquals(listOf("new"), viewModel.state.value.rows.map { it.id })
        assertFalse(viewModel.state.value.refreshing)
    }

    @Test fun `old A callback remains rejected after B and a fresh A login reuse its id`() = runTest {
        signIn(accountA)
        showRows(accountA, row("shared-id"))
        val firstAGeneration = viewModel.state.value.ownerGeneration
        signIn(accountB)
        showRows(accountB, row("b-row"))
        signIn(accountA)
        showRows(accountA, row("shared-id"))

        assertNull(viewModel.rowForOpen("shared-id", firstAGeneration))
        assertEquals("shared-id", viewModel.rowForOpen(
            "shared-id", viewModel.state.value.ownerGeneration,
        )?.id)
    }

    @Test fun `active owner offline read queues exactly one payload with captured owner`() = runTest {
        markReadAnswer = { Result.failure(IOException("offline")) }
        signIn(accountA)
        showRows(accountA, row("a-row"))

        viewModel.markRead("a-row")
        runCurrent()

        val payload = slot<String>()
        coVerify(exactly = 1) {
            outbox.enqueue(OutboxKinds.NOTIFICATION_READ, capture(payload))
        }
        val decoded = Json.decodeFromString(NotificationReadPayload.serializer(), payload.captured)
        assertEquals("a-row", decoded.notificationId)
        assertEquals(accountA, decoded.userId)
    }

    @Test fun `late noncooperative A stream error cannot disturb B or block its subscription`() = runTest {
        val oldStream = NonCooperativeReply<Unit>()
        every { repository.observeNotifications(accountA) } answers {
            observeCalls += accountA
            flow {
                emit(listOf(row("a-row")))
                oldStream.await() // deliberately ignores cancellation
                throw IOException("old A socket failed")
            }
        }
        signIn(accountA)
        assertEquals(listOf("a-row"), viewModel.state.value.rows.map { it.id })

        signIn(accountB)
        showRows(accountB, row("b-row"))
        assertEquals(listOf(accountA, accountB), observeCalls)
        oldStream.complete(Unit)
        runCurrent()

        assertEquals(listOf("b-row"), viewModel.state.value.rows.map { it.id })
        assertNull(viewModel.state.value.errorMessage)
    }

    @Test fun `stream reconnect cannot clear a pending manual refresh and admit a second request`() = runTest {
        val oldStream = NonCooperativeReply<Unit>()
        val pendingRefresh = NonCooperativeReply<Result<List<Notification>>>()
        every { repository.observeNotifications(accountA) } answers {
            observeCalls += accountA
            flow {
                emit(listOf(row("a-row")))
                oldStream.await()
                throw IOException("socket reconnected")
            }
        }
        refreshAnswer = { pendingRefresh.await() }
        signIn(accountA)
        viewModel.refresh()
        runCurrent()
        assertTrue(viewModel.state.value.refreshing)

        oldStream.complete(Unit)
        runCurrent()
        assertTrue("reconnect must not complete a pending manual refresh", viewModel.state.value.refreshing)
        viewModel.refresh()
        runCurrent()
        assertEquals(listOf(accountA), refreshCalls)

        pendingRefresh.complete(Result.success(listOf(row("refreshed"))))
        runCurrent()
        assertEquals(listOf("refreshed"), viewModel.state.value.rows.map { it.id })
        assertFalse(viewModel.state.value.refreshing)
    }

    @Test fun `manual refresh timeout ends spinner even when repository ignores cancellation`() = runTest {
        val pending = NonCooperativeReply<Result<List<Notification>>>()
        refreshAnswer = { pending.await() }
        signIn(accountA)
        showRows(accountA, row("a-row"))
        viewModel.refresh()
        runCurrent()
        assertTrue(viewModel.state.value.refreshing)

        advanceTimeBy(3_001)
        runCurrent()

        assertFalse(viewModel.state.value.refreshing)
        assertEquals(listOf("a-row"), viewModel.state.value.rows.map { it.id })
        pending.complete(Result.success(listOf(row("late"))))
        runCurrent()
        assertEquals(listOf("a-row"), viewModel.state.value.rows.map { it.id })
    }

    private fun TestScope.signIn(userId: String, email: String? = null) {
        auth.setSession(AuthSession.SignedIn(userId, email))
        runCurrent()
    }

    private fun TestScope.showRows(userId: String, vararg rows: Notification) {
        val stream = streams[userId]
        assertTrue("Expected observeNotifications($userId) to be called", stream != null)
        assertEquals("Expected one active $userId subscription", 1, stream!!.subscriptionCount.value)
        assertTrue(stream.tryEmit(rows.toList()))
        runCurrent()
    }

    private fun row(id: String) = Notification(
        id = id,
        title = "Synthetic $id",
        body = "Offline test notification",
        kind = null,
        data = emptyMap(),
        sentAt = Instant.parse("2026-09-28T00:00:00Z"),
        readAt = null,
        deepLink = null,
    )

    /** A suspend reply that can resume even after its caller's Job is cancelled. */
    private class NonCooperativeReply<T> {
        private var continuation: Continuation<T>? = null

        suspend fun await(): T = suspendCoroutine { continuation = it }

        fun complete(value: T) {
            val pending = checkNotNull(continuation) { "Reply was not awaited" }
            continuation = null
            pending.resume(value)
        }
    }
}
