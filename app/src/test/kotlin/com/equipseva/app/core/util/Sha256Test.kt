package com.equipseva.app.core.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * round3820 — the client-side hash that feeds `evidence_ledger.content_sha256`
 * must be byte-for-byte what Postgres computes with
 * `encode(extensions.digest(bytes, 'sha256'), 'hex')`. Pinned against the
 * FIPS 180-4 test vectors and the exact value the round3818 prod probe
 * produced for "abc".
 */
class Sha256Test {

    @Test fun `abc matches the FIPS vector and the prod digest probe`() {
        assertEquals(
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
            "abc".toByteArray().sha256Hex(),
        )
    }

    @Test fun `empty input has the well-known empty digest`() {
        assertEquals(
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
            ByteArray(0).sha256Hex(),
        )
    }

    @Test fun `output is always 64 lowercase hex chars`() {
        val hex = ByteArray(1000) { (it * 31).toByte() }.sha256Hex()
        assertEquals(64, hex.length)
        assertTrue(hex, Regex("^[0-9a-f]{64}$").matches(hex))
    }
}
