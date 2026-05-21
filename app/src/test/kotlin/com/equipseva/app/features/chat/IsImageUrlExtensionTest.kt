package com.equipseva.app.features.chat

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the image-extension detection for chat attachments. Supabase
 * signed-URL paths carry a `?token=...` query string after the
 * filename; the gate strips that before matching the extension. A
 * regression that forgot the substringBefore would silently render
 * every signed URL as a generic file-pill (the AsyncImage branch
 * would never trigger).
 *
 * Six extensions accepted — jpg/jpeg/png/webp/gif/heic. Pin so a
 * future extension addition is intentional + symmetric (e.g. add
 * avif without forgetting it).
 */
class IsImageUrlExtensionTest {

    @Test fun `plain jpg path is an image`() {
        assertTrue(isImageUrlExtension("https://cdn.example/photo.jpg"))
    }

    @Test fun `jpeg variant is an image`() {
        assertTrue(isImageUrlExtension("photo.jpeg"))
    }

    @Test fun `png is an image`() {
        assertTrue(isImageUrlExtension("photo.png"))
    }

    @Test fun `webp is an image`() {
        assertTrue(isImageUrlExtension("photo.webp"))
    }

    @Test fun `gif is an image (chat does render animated)`() {
        assertTrue(isImageUrlExtension("photo.gif"))
    }

    @Test fun `heic from iPhones is an image`() {
        assertTrue(isImageUrlExtension("photo.heic"))
    }

    @Test fun `uppercase extension matches (case-insensitive)`() {
        assertTrue(isImageUrlExtension("photo.JPG"))
        assertTrue(isImageUrlExtension("photo.HEIC"))
        assertTrue(isImageUrlExtension("photo.PNG"))
    }

    @Test fun `mixed-case extension matches`() {
        assertTrue(isImageUrlExtension("photo.Jpg"))
    }

    @Test fun `query string after extension is ignored`() {
        // Supabase signed URLs carry ?token=...; the gate strips
        // before matching. Critical for the AsyncImage branch.
        assertTrue(isImageUrlExtension(
            "https://x.supabase.co/photo.jpg?token=eyJhbGciOiJIUzI1NiI",
        ))
        assertTrue(isImageUrlExtension("photo.png?download=1&width=720"))
    }

    @Test fun `query parameters between path and extension are NOT stripped`() {
        // Defensive — the gate strips only the FIRST '?'. A URL
        // shaped like "photo?.jpg" (no real-world example) would
        // fold to "photo" which is not an image. Pin so the
        // simple substringBefore semantics stay obvious.
        assertFalse(isImageUrlExtension("photo?.jpg"))
    }

    @Test fun `non-image extensions are NOT images`() {
        assertFalse(isImageUrlExtension("doc.pdf"))
        assertFalse(isImageUrlExtension("video.mp4"))
        assertFalse(isImageUrlExtension("audio.mp3"))
        assertFalse(isImageUrlExtension("data.csv"))
        assertFalse(isImageUrlExtension("readme.txt"))
    }

    @Test fun `no extension folds to false`() {
        assertFalse(isImageUrlExtension("https://cdn.example/photo"))
        assertFalse(isImageUrlExtension("photo"))
    }

    @Test fun `empty url folds to false`() {
        assertFalse(isImageUrlExtension(""))
    }

    @Test fun `extension that matches a prefix is rejected`() {
        // ".jpge" / ".jpgs" must NOT match — endsWith is exact.
        assertFalse(isImageUrlExtension("photo.jpge"))
        assertFalse(isImageUrlExtension("photo.jpgs"))
    }

    @Test fun `Supabase signed-url path with full bucket prefix detects correctly`() {
        // Concrete example: a real signed URL from Supabase Storage.
        val url =
            "https://abc.supabase.co/storage/v1/object/sign/chat-attachments/u-1/2026/05/photo.jpg?token=abc.def.ghi"
        assertTrue(isImageUrlExtension(url))
    }
}
