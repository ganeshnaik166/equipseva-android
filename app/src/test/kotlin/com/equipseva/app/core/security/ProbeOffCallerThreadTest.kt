package com.equipseva.app.core.security

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNotSame
import org.junit.Test
import java.util.concurrent.CountDownLatch

/**
 * Pins the wrapper the device-integrity socket probe runs behind. The
 * regression target: the probe used to run inline on whichever thread
 * asked, and every caller is the main thread, where Android throws
 * NetworkOnMainThreadException even for a loopback connect — so the Frida
 * signal reported "clean" on every device in the field.
 */
class ProbeOffCallerThreadTest {

    @Test fun `the probe result is what the caller gets`() {
        assertEquals("ok", probeOffCallerThread("probe-test", 1_000L, "unavailable") { "ok" })
    }

    @Test fun `the probe never runs on the calling thread`() {
        val caller = Thread.currentThread()
        val ran = probeOffCallerThread<Thread?>("probe-test-identity", 1_000L, null) {
            Thread.currentThread()
        }
        assertNotNull("probe did not complete within the join window", ran)
        assertNotSame(caller, ran)
        assertEquals("probe-test-identity", ran?.name)
    }

    @Test fun `a probe that throws yields the fallback`() {
        // NetworkOnMainThreadException was the real case: a throwing probe
        // must read as the negative answer, never propagate into boot.
        assertEquals(
            false,
            probeOffCallerThread("probe-test-throwing", 1_000L, false) {
                throw IllegalStateException("probe unavailable")
            },
        )
    }

    @Test fun `a probe slower than the join window yields the fallback`() {
        // A hung probe must not stall a cold start; the periodic re-check
        // is what recovers the missed signal.
        val release = CountDownLatch(1)
        try {
            assertEquals(
                "unavailable",
                probeOffCallerThread("probe-test-slow", 20L, "unavailable") {
                    release.await()
                    "late"
                },
            )
        } finally {
            release.countDown()
        }
    }
}
