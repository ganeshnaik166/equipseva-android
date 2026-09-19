package com.equipseva.app.core.sync

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins that two drains cannot overlap.
 *
 * The periodic flush and the enqueue-triggered one-shot are separate unique
 * work names, so WorkManager may start both at the same instant (a reconnect
 * satisfies both network constraints at once). The `outbox` table has no claim
 * column, so overlapping runs read the same rows: the same chat message was
 * inserted twice and one failure was charged two attempts. Until a claim
 * column exists, this lock IS the invariant.
 */
class OutboxDrainLockTest {

    @Test fun `a second drain waits for the first to finish`() = runTest {
        val lock = OutboxDrainLock()
        val events = mutableListOf<String>()
        val firstReachedTheMiddle = CompletableDeferred<Unit>()
        val letFirstFinish = CompletableDeferred<Unit>()

        val first = launch {
            lock.withDrain {
                events += "first-in"
                firstReachedTheMiddle.complete(Unit)
                letFirstFinish.await()
                events += "first-out"
            }
        }
        firstReachedTheMiddle.await()

        val second = launch {
            lock.withDrain {
                events += "second-in"
                events += "second-out"
            }
        }
        // The second drain is now started and suspended on the lock: nothing
        // of it may appear before the first one has left.
        letFirstFinish.complete(Unit)
        first.join()
        second.join()

        assertEquals(listOf("first-in", "first-out", "second-in", "second-out"), events)
    }

    @Test fun `the lock is released when a drain throws`() = runTest {
        // A handler that escapes with an exception, or WorkManager cancelling
        // the drain, must not leave the process unable to ever drain again.
        val lock = OutboxDrainLock()
        var thrown: Throwable? = null
        try {
            lock.withDrain { throw IllegalStateException("drain blew up") }
        } catch (expected: IllegalStateException) {
            thrown = expected
        }
        assertEquals("drain blew up", thrown?.message)

        assertEquals("drained", lock.withDrain { "drained" })
    }

    @Test fun `the lock returns the drain result unchanged`() = runTest {
        val lock = OutboxDrainLock()
        assertEquals(7, lock.withDrain { 7 })
    }
}
