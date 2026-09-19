package com.equipseva.app.core.sync.handlers

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the upload timeout against the stash's own size cap.
 *
 * A single 60-second cap could not carry [PhotoUploadPayload.MAX_FILE_SIZE_BYTES]
 * (15 MB, the KYC bucket's limit) on a weak link: a large identity document
 * timed out on every attempt, restarted from byte zero — these uploads are not
 * resumable — and was eventually dropped with "Couldn't upload a photo". Since
 * re-attaching the same file reproduced it exactly, the user had no way
 * through at all. The two ends that matter are therefore pinned together: the
 * largest file the stash accepts must get a workable budget, and no file may
 * get a budget that outlives WorkManager's 10-minute execution window.
 */
class UploadTimeoutForTest {

    private val oneMb = 1024L * 1024L

    @Test fun `a three megabyte photo gets ninety seconds`() {
        // The size the old fixed cap was actually sized for; it stays roughly
        // where it was so ordinary repair photos see no change in behaviour.
        assertEquals(90_000L, uploadTimeoutFor(3 * oneMb))
    }

    @Test fun `the fifteen megabyte stash cap gets at least five and a half minutes`() {
        val atCap = uploadTimeoutFor(PhotoUploadPayload.MAX_FILE_SIZE_BYTES)
        assertTrue("got ${atCap}ms for the 15 MB cap", atCap >= 330_000L)
    }

    @Test fun `the budget never outlives WorkManager's execution window`() {
        // WorkManager stops a worker after 10 minutes; a timeout beyond that
        // would be enforced by the runtime killing the drain mid-upload
        // instead of by the handler returning a Retry.
        val absurd = uploadTimeoutFor(Long.MAX_VALUE)
        assertTrue("got ${absurd}ms", absurd in 1L..480_000L)
        assertEquals(absurd, uploadTimeoutFor(10L * 1024 * oneMb))
    }

    @Test fun `a tiny or missing file still gets the handshake floor`() {
        // Zero and negative are defensive: File.length() answers 0 for a file
        // that vanished between the stat and the read.
        assertEquals(30_000L, uploadTimeoutFor(0L))
        assertEquals(30_000L, uploadTimeoutFor(-1L))
        assertEquals(50_000L, uploadTimeoutFor(1L))
    }

    @Test fun `the budget grows with size and never shrinks`() {
        var previous = uploadTimeoutFor(0L)
        for (mb in 1..20) {
            val current = uploadTimeoutFor(mb * oneMb)
            assertTrue("$mb MB: $current < $previous", current >= previous)
            previous = current
        }
    }
}
