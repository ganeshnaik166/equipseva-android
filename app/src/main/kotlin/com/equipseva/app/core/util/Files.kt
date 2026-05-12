package com.equipseva.app.core.util

/**
 * Build a timestamp-prefixed, sanitized object-name for storage uploads.
 * Strips any directory component from `original`, replaces anything outside
 * `[A-Za-z0-9._-]` with `_`, and prepends `<epochMillis>-`. The `fallback`
 * is used when the original (after stripping) is blank.
 *
 * Defense-in-depth: keeps RLS-relevant path segments well-formed before
 * StorageRepository.validatePath runs as a second guard at the bucket.
 */
fun timestampedName(original: String, fallback: String = "file"): String {
    val sanitized = original.substringAfterLast('/').ifBlank { fallback }
        .replace(Regex("[^A-Za-z0-9._-]"), "_")
    return "${System.currentTimeMillis()}-$sanitized"
}
