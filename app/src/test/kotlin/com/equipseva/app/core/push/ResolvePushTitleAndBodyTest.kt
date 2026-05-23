package com.equipseva.app.core.push

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ResolvePushTitleAndBodyTest {

    private val app = "EquipSeva"

    @Test fun `both null returns null (drop the push)`() {
        // Critical pin — bare app name with empty subtitle is useless
        // to the user. The caller MUST drop the push instead of posting
        // a blank notification. A refactor that returned ("EquipSeva",
        // "") here would surface ghost notifications on every payload-
        // less FCM ping (e.g. token-only refreshes the server sent
        // accidentally as a notification).
        assertNull(resolvePushTitleAndBody(rawTitle = null, rawBody = null, fallbackTitle = app))
    }

    @Test fun `both blank returns null (drop the push)`() {
        assertNull(resolvePushTitleAndBody("", "   ", app))
        assertNull(resolvePushTitleAndBody("   ", "", app))
    }

    @Test fun `null title with body uses fallback app name`() {
        val pair = resolvePushTitleAndBody(rawTitle = null, rawBody = "Bid accepted", fallbackTitle = app)
        assertEquals(app to "Bid accepted", pair)
    }

    @Test fun `blank-but-not-null title is preserved (system fills app name from channel)`() {
        // Pin — only NULL triggers the fallback. A blank-but-present
        // title is treated as the server's explicit choice; Android's
        // notification system surfaces the app name from the channel
        // metadata in that case. A refactor that folded blank → null
        // would change behaviour here.
        val pair = resolvePushTitleAndBody(rawTitle = "", rawBody = "Bid accepted", fallbackTitle = app)
        assertEquals("" to "Bid accepted", pair)
    }

    @Test fun `null body becomes empty string`() {
        val pair = resolvePushTitleAndBody(rawTitle = "New bid", rawBody = null, fallbackTitle = app)
        assertEquals("New bid" to "", pair)
    }

    @Test fun `title is capped at PUSH_TITLE_MAX_CHARS`() {
        // Critical pin — IPC Bundle 1MB ceiling. A malformed server
        // payload (or a pasted blob) must NOT push the Bundle past the
        // limit; the system crashes notify() with TransactionTooLarge.
        val giant = "x".repeat(PUSH_TITLE_MAX_CHARS + 50)
        val pair = resolvePushTitleAndBody(rawTitle = giant, rawBody = "body", fallbackTitle = app)
        assertEquals(PUSH_TITLE_MAX_CHARS, pair?.first?.length)
    }

    @Test fun `body is capped at PUSH_BODY_MAX_CHARS`() {
        val giant = "y".repeat(PUSH_BODY_MAX_CHARS + 50)
        val pair = resolvePushTitleAndBody(rawTitle = "t", rawBody = giant, fallbackTitle = app)
        assertEquals(PUSH_BODY_MAX_CHARS, pair?.second?.length)
    }

    @Test fun `cap constants are PUSH_TITLE_MAX_CHARS 200 + PUSH_BODY_MAX_CHARS 1000`() {
        // Wire-frozen pin. Conservative thresholds — real titles fit
        // in 80 chars and real bodies in 240; the 200/1000 cap leaves
        // plenty of margin while keeping the Bundle well under 1MB.
        // A refactor that bumped these without checking the Bundle
        // ceiling would re-introduce the TransactionTooLargeException
        // crash class.
        assertEquals(200, PUSH_TITLE_MAX_CHARS)
        assertEquals(1000, PUSH_BODY_MAX_CHARS)
    }

    @Test fun `fallback longer than maxTitleChars still gets capped`() {
        // Defensive — caller passes the app name (short) so this
        // doesn't fire in production, but a misconfigured fallback
        // shouldn't bypass the cap.
        val pair = resolvePushTitleAndBody(
            rawTitle = null,
            rawBody = "body",
            fallbackTitle = "x".repeat(250),
            maxTitleChars = 100,
        )
        assertEquals(100, pair?.first?.length)
    }

    @Test fun `title-only short message round-trips unchanged`() {
        val pair = resolvePushTitleAndBody("Bid accepted", "", app)
        assertEquals("Bid accepted" to "", pair)
    }
}
