package com.equipseva.app.core.sync

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.IOException

/**
 * Contract test for the [OutboxKindHandler.Outcome] sealed type. Every handler
 * — and the OutboxWorker that consumes them — switches on the three cases
 * (Success / Retry / GiveUp). Pinning the shape here makes a silent change
 * (e.g. swapping `Retry`'s reason from Throwable → String, or making Success
 * carry data) surface as a test failure rather than rippling through every
 * handler test individually.
 */
class OutboxKindHandlerOutcomeTest {

    @Test fun `Success is a singleton — every reference is the same instance`() {
        // Worker code can use referential equality on Success without ceremony.
        val a: OutboxKindHandler.Outcome = OutboxKindHandler.Outcome.Success
        val b: OutboxKindHandler.Outcome = OutboxKindHandler.Outcome.Success

        assertSame(a, b)
    }

    @Test fun `Retry carries the underlying throwable so it can be logged`() {
        val cause = IOException("offline")
        val retry = OutboxKindHandler.Outcome.Retry(cause)

        assertSame(cause, retry.reason)
        assertTrue(retry.reason is IOException)
    }

    @Test fun `GiveUp carries a human-readable reason string`() {
        // GiveUp is the poison-drop path; the worker logs `reason` and the
        // user gets the kind-level copy from PoisonDropCopy.
        val giveUp = OutboxKindHandler.Outcome.GiveUp("Malformed payload: bad field")

        assertEquals("Malformed payload: bad field", giveUp.reason)
    }

    @Test fun `Retry equality is by cause — same throwable instance compares equal`() {
        // Data class equality lets us assert on a specific Retry in handler
        // tests without resorting to instanceof + property reads.
        val cause = IOException("offline")
        val a = OutboxKindHandler.Outcome.Retry(cause)
        val b = OutboxKindHandler.Outcome.Retry(cause)

        assertEquals(a, b)
    }

    @Test fun `GiveUp equality is by reason string`() {
        val a = OutboxKindHandler.Outcome.GiveUp("dup-reason")
        val b = OutboxKindHandler.Outcome.GiveUp("dup-reason")
        val c = OutboxKindHandler.Outcome.GiveUp("other")

        assertEquals(a, b)
        assertNotEquals(a, c)
    }

    @Test fun `outcomes of different cases are not equal to each other`() {
        // Sanity: a Retry must never be `==` to a GiveUp or Success even when
        // the worker's when-branch only checks one of them.
        val retry: OutboxKindHandler.Outcome = OutboxKindHandler.Outcome.Retry(IOException("x"))
        val giveUp: OutboxKindHandler.Outcome = OutboxKindHandler.Outcome.GiveUp("x")
        val success: OutboxKindHandler.Outcome = OutboxKindHandler.Outcome.Success

        assertNotEquals(retry, giveUp)
        assertNotEquals(retry, success)
        assertNotEquals(giveUp, success)
    }

    @Test fun `exhaustive when over Outcome compiles and dispatches correctly`() {
        // This is the shape every handler-consumer (OutboxWorker) relies on:
        // an exhaustive when with three branches. If a new case is ever
        // added to the sealed type without updating consumers, this test
        // body would stop compiling — surfacing the omission at build time.
        val cases: List<OutboxKindHandler.Outcome> = listOf(
            OutboxKindHandler.Outcome.Success,
            OutboxKindHandler.Outcome.Retry(IOException("io")),
            OutboxKindHandler.Outcome.GiveUp("done"),
        )
        val tags = cases.map { outcome ->
            when (outcome) {
                is OutboxKindHandler.Outcome.Success -> "success"
                is OutboxKindHandler.Outcome.Retry -> "retry"
                is OutboxKindHandler.Outcome.GiveUp -> "giveup"
            }
        }
        assertEquals(listOf("success", "retry", "giveup"), tags)
        // Belt-and-braces: confirm each branch is reachable.
        assertNotNull(tags)
    }
}
