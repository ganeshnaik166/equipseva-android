package com.equipseva.app.core.util

import java.security.MessageDigest

/**
 * round3820 — SHA-256 of this byte array as 64 lowercase hex characters,
 * the exact shape `evidence_ledger.content_sha256` accepts
 * (`^[0-9a-f]{64}$`) and the one `verify_evidence_hash()` recomputes.
 */
fun ByteArray.sha256Hex(): String {
    val digest = MessageDigest.getInstance("SHA-256").digest(this)
    val out = CharArray(digest.size * 2)
    val hex = "0123456789abcdef"
    digest.forEachIndexed { i, b ->
        val v = b.toInt() and 0xff
        out[i * 2] = hex[v ushr 4]
        out[i * 2 + 1] = hex[v and 0x0f]
    }
    return String(out)
}
