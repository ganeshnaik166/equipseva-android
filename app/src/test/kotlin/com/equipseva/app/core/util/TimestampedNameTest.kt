package com.equipseva.app.core.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins [timestampedName] sanitization. The timestamp prefix is
 * tested by shape (starts with digits then "-") rather than exact
 * value because System.currentTimeMillis() is non-deterministic.
 */
class TimestampedNameTest {

    private fun suffix(out: String): String = out.substringAfter("-")

    @Test fun `output starts with epoch-millis dash`() {
        val out = timestampedName("photo.jpg")
        // Format is "<long>-<sanitized>". Pin the dash position is
        // valid and the prefix parses as Long.
        val dashIndex = out.indexOf('-')
        assertTrue(dashIndex > 0)
        out.substring(0, dashIndex).toLong() // throws if not numeric
    }

    @Test fun `clean filename passes through after timestamp`() {
        assertEquals("photo.jpg", suffix(timestampedName("photo.jpg")))
    }

    @Test fun `directory components stripped`() {
        // Pin substringAfterLast('/') — directory path components
        // must not leak into storage object key.
        assertEquals(
            "report.pdf",
            suffix(timestampedName("/some/dir/path/report.pdf")),
        )
    }

    @Test fun `unsafe characters replaced with underscore`() {
        // [^A-Za-z0-9._-] replaced with '_'. Pin so a refactor that
        // changed the allowlist doesn't break the storage RLS path.
        assertEquals(
            "my_photo__1_.jpg",
            suffix(timestampedName("my photo (1).jpg")),
        )
    }

    @Test fun `dots underscores hyphens preserved`() {
        // Pin allowed character set.
        assertEquals(
            "file.name-with_chars.png",
            suffix(timestampedName("file.name-with_chars.png")),
        )
    }

    @Test fun `blank original uses fallback`() {
        assertEquals("file", suffix(timestampedName("")))
    }

    @Test fun `whitespace-only original uses fallback`() {
        // After substringAfterLast('/'), ifBlank fires.
        assertEquals("file", suffix(timestampedName("   ")))
    }

    @Test fun `custom fallback used when original is blank`() {
        assertEquals(
            "avatar",
            suffix(timestampedName("", fallback = "avatar")),
        )
    }

    @Test fun `directory-only path uses fallback`() {
        // substringAfterLast('/') on "dir/" returns "".
        assertEquals(
            "file",
            suffix(timestampedName("dir/")),
        )
    }

    @Test fun `Devanagari digits get sanitized to underscores`() {
        // Critical pin — non-ASCII characters get replaced. Storage
        // keys must stay ASCII for cross-system safety.
        val out = suffix(timestampedName("photo१२३.jpg"))
        assertTrue(out.contains("photo___.jpg"))
    }

    @Test fun `consecutive calls produce different timestamps (non-deterministic by design)`() {
        // Sanity check — timestamps tick. Sleep briefly to ensure
        // System.currentTimeMillis advances.
        val a = timestampedName("x.jpg")
        Thread.sleep(5)
        val b = timestampedName("x.jpg")
        assertNotEquals(a, b)
    }
}
