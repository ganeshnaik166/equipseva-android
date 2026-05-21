package com.equipseva.app.core.push

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the push payload channel-id sanitizer. The server's FCM payload
 * carries `channel` as one of three known ids; anything else (blank,
 * legacy "orders", future-but-unsupported) folds to ACCOUNT so the
 * notification still surfaces.
 *
 * The fallback is critical: NotificationCompat silently drops posts
 * with a blank or unknown channel id on API 26+, so a malformed
 * server send would otherwise vanish entirely. ACCOUNT is the safest
 * bucket (KYC / security copy is the most common landing).
 */
class ResolvePushChannelTest {

    @Test fun `jobs channel passes through verbatim`() {
        assertEquals(NotificationChannels.JOBS, resolvePushChannel(NotificationChannels.JOBS))
    }

    @Test fun `chat channel passes through verbatim`() {
        assertEquals(NotificationChannels.CHAT, resolvePushChannel(NotificationChannels.CHAT))
    }

    @Test fun `account channel passes through verbatim`() {
        assertEquals(NotificationChannels.ACCOUNT, resolvePushChannel(NotificationChannels.ACCOUNT))
    }

    @Test fun `null channel folds to ACCOUNT (not blank)`() {
        // The Elvis fallback in onMessageReceived previously let a
        // null channel through to NotificationCompat.Builder and the
        // post silently dropped. Pin the ACCOUNT fallback.
        assertEquals(NotificationChannels.ACCOUNT, resolvePushChannel(null))
    }

    @Test fun `blank channel folds to ACCOUNT`() {
        // Server-side bug shipped empty-string `channel` in some early
        // pushes — the takeIf{isNotBlank} guard catches it now.
        assertEquals(NotificationChannels.ACCOUNT, resolvePushChannel(""))
        assertEquals(NotificationChannels.ACCOUNT, resolvePushChannel("   "))
    }

    @Test fun `legacy orders channel folds to ACCOUNT (was retired in v1)`() {
        // Pre-v1 builds had an "orders" marketplace channel; the
        // marketplace shipped off, but a returning user on an older
        // build could still receive a server-side "orders" push.
        // Fall back to ACCOUNT so it surfaces.
        assertEquals(NotificationChannels.ACCOUNT, resolvePushChannel("orders"))
    }

    @Test fun `unknown future channel folds to ACCOUNT`() {
        // Forward-compat — a new channel id on the server before the
        // client knows about it surfaces under ACCOUNT rather than
        // disappearing. Pin so a future "drop unknown" refactor is
        // reviewed.
        assertEquals(NotificationChannels.ACCOUNT, resolvePushChannel("future_channel"))
    }

    @Test fun `channel matching is case-sensitive`() {
        // Server emits lowercase; mixed case must NOT match to keep
        // the wire format strict. Pin so a "tolerant lowercase()"
        // refactor surfaces.
        assertEquals(NotificationChannels.ACCOUNT, resolvePushChannel("JOBS"))
        assertEquals(NotificationChannels.ACCOUNT, resolvePushChannel("Chat"))
    }
}
