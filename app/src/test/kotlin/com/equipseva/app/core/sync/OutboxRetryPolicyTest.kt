package com.equipseva.app.core.sync

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.TimeUnit

/**
 * Pins when a queued write is allowed to be destroyed.
 *
 * The queue holds writes the user was told had been accepted — a bid, a job
 * status flip, a chat message, a photo's evidence registration. Deleting one
 * is the most damaging thing the sync layer can do, so the conditions are
 * pinned here rather than left implicit in the worker's loop:
 *
 *   * attempts alone must NOT be enough. With a 15-minute tick and a 5-attempt
 *     cap, the old policy destroyed the queue after ~75 minutes of any
 *     transient failure — one PostgREST schema-cache reload, one Supabase
 *     incident, one unrefreshed token — and told the user their writes had
 *     been discarded.
 *   * a precondition the payload cannot influence (no restored session yet)
 *     must not spend attempts at all, which is what [OutboxKindHandler.Outcome.Retry]'s
 *     budget flag is for.
 *
 * Permanent failures do not depend on any of this: they leave through GiveUp
 * (see [OutboxErrorClassifierTest]) on their first sighting.
 */
class OutboxRetryPolicyTest {

    private val oneDayMs = TimeUnit.HOURS.toMillis(24)

    @Test fun `out of attempts but young is not poison`() {
        // The whole point: an entry can burn every attempt inside a single
        // outage. Age is what distinguishes an outage from a poison payload.
        assertFalse(outboxEntryIsPoison(OUTBOX_POISON_ATTEMPT_FLOOR, TimeUnit.HOURS.toMillis(1)))
        assertFalse(outboxEntryIsPoison(OUTBOX_POISON_ATTEMPT_FLOOR + 40, TimeUnit.HOURS.toMillis(23)))
    }

    @Test fun `old but with attempts to spare is not poison`() {
        // A row that sat in the queue for a week because the device was
        // offline has not failed anything yet.
        assertFalse(outboxEntryIsPoison(1, TimeUnit.DAYS.toMillis(7)))
        assertFalse(outboxEntryIsPoison(OUTBOX_POISON_ATTEMPT_FLOOR - 1, TimeUnit.DAYS.toMillis(7)))
    }

    @Test fun `out of attempts and a day old is poison`() {
        assertTrue(outboxEntryIsPoison(OUTBOX_POISON_ATTEMPT_FLOOR, oneDayMs))
        assertTrue(outboxEntryIsPoison(OUTBOX_POISON_ATTEMPT_FLOOR + 1, oneDayMs + 1))
    }

    @Test fun `both thresholds are inclusive`() {
        // Pinned because an off-by-one on either side is invisible in
        // production: the row simply survives one more tick, or dies one
        // tick early.
        assertTrue(outboxEntryIsPoison(OUTBOX_POISON_ATTEMPT_FLOOR, OUTBOX_POISON_MIN_AGE_MS))
        assertFalse(outboxEntryIsPoison(OUTBOX_POISON_ATTEMPT_FLOOR - 1, OUTBOX_POISON_MIN_AGE_MS))
        assertFalse(outboxEntryIsPoison(OUTBOX_POISON_ATTEMPT_FLOOR, OUTBOX_POISON_MIN_AGE_MS - 1))
    }

    @Test fun `a clock that moved backwards cannot poison an entry`() {
        // createdAt is device wall-clock, so `now - createdAt` can come out
        // negative after a timezone / NTP correction. Retaining the row is
        // the only safe reading of a negative age.
        assertFalse(outboxEntryIsPoison(OUTBOX_POISON_ATTEMPT_FLOOR + 5, -TimeUnit.DAYS.toMillis(2)))
    }

    @Test fun `age floor is a full day and the attempt floor is not the old five`() {
        assertEquals(oneDayMs, OUTBOX_POISON_MIN_AGE_MS)
        assertTrue("five attempts was ~75 minutes of outage", OUTBOX_POISON_ATTEMPT_FLOOR > 5)
    }

    @Test fun `a Retry charges the budget unless it says otherwise`() {
        // Default-true matters: every handler that reports a genuine network
        // failure uses the one-argument form, and those must keep counting.
        assertTrue(OutboxKindHandler.Outcome.Retry(RuntimeException("5xx")).countsAgainstBudget)
        assertFalse(
            OutboxKindHandler.Outcome.Retry(
                IllegalStateException("No auth session"),
                countsAgainstBudget = false,
            ).countsAgainstBudget,
        )
    }
}
