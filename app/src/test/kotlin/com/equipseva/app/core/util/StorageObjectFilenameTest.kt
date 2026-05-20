package com.equipseva.app.core.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Shared storage-key builder used by both [kycTimestampedName] and the
 * booking form's photo uploader. The behaviour was previously duplicated
 * across two separate helpers; consolidating it here lets one suffix
 * transform serve both call sites.
 */
class StorageObjectFilenameTest {

    @Test fun `default fallback is file`() {
        val name = storageObjectFilename("path/to/")
        assertTrue("expected -file tail in $name", name.endsWith("-file"))
    }

    @Test fun `custom fallback is used for blank tails`() {
        val name = storageObjectFilename("path/to/", blankFallback = "photo.jpg")
        assertTrue("expected -photo.jpg tail in $name", name.endsWith("-photo.jpg"))
    }

    @Test fun `drops everything before the last slash`() {
        val name = storageObjectFilename("content://com.android.providers.media/document/aadhaar.jpg")
        assertTrue("expected -aadhaar.jpg tail in $name", name.endsWith("-aadhaar.jpg"))
    }

    @Test fun `collapses unsafe chars to underscore`() {
        // Supabase Storage rejects keys with spaces / parentheses / unicode.
        val name = storageObjectFilename("my doc (final).pdf")
        assertTrue("expected sanitised tail in $name", name.endsWith("-my_doc__final_.pdf"))
    }

    @Test fun `preserves the dot, underscore, dash allow-list`() {
        val name = storageObjectFilename("a.b_c-d.png")
        assertTrue("expected exact tail in $name", name.endsWith("-a.b_c-d.png"))
    }

    @Test fun `epoch prefix is numeric and positive`() {
        val name = storageObjectFilename("doc.pdf")
        val parts = name.split("-", limit = 2)
        assertEquals(2, parts.size)
        assertTrue("expected numeric prefix in ${parts[0]}", parts[0].toLongOrNull() != null)
        assertTrue("expected positive epoch in ${parts[0]}", parts[0].toLong() > 0)
        assertEquals("doc.pdf", parts[1])
    }

    @Test fun `empty input falls back to the default`() {
        val name = storageObjectFilename("")
        assertTrue("expected -file tail in $name", name.endsWith("-file"))
    }

    @Test fun `single-segment input is preserved`() {
        val name = storageObjectFilename("avatar.jpg")
        assertTrue("expected -avatar.jpg tail in $name", name.endsWith("-avatar.jpg"))
    }
}
