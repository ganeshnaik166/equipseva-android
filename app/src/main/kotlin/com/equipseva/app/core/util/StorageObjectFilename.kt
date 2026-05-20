package com.equipseva.app.core.util

/**
 * Builds a storage-safe upload filename for a Supabase Storage object key:
 * `{epoch}-{sanitised-tail}`. The tail is the trailing path segment (so
 * SAF-returned URIs that carry a path prefix get collapsed to just the
 * file name), with anything outside `[A-Za-z0-9._-]` replaced by `_`.
 * Falls back to [blankFallback] when the tail is empty after stripping.
 *
 * The timestamp prefix is taken from `System.currentTimeMillis()` so
 * concurrent uploads from the same user don't collide on object key.
 *
 * The suffix transform is pure; tests pin the post-dash portion (e.g.
 * `endsWith("-aadhaar.jpg")`) without locking the wall-clock prefix.
 */
internal fun storageObjectFilename(
    original: String,
    blankFallback: String = "file",
): String {
    val sanitized = original.substringAfterLast('/').ifBlank { blankFallback }
        .replace(Regex("[^A-Za-z0-9._-]"), "_")
    val stamp = System.currentTimeMillis()
    return "$stamp-$sanitized"
}
