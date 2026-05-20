package com.equipseva.app.features.kyc

import com.equipseva.app.core.data.engineers.EngineerCertificate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the `certificates` jsonb payload assembled inside [KycViewModel.save].
 *
 * Order is load-bearing: [com.equipseva.app.core.data.engineers.Engineer]
 * resolves the displayed Aadhaar / PAN path via `lastOrNull { type == X }`,
 * so any reordering in the builder would silently flip which entry wins
 * after a re-submit. These tests pin both the elements written AND the
 * order they're written in.
 */
class KycCertificatesBuilderTest {

    private val now = "2026-05-20T00:00:00Z"

    @Test fun `builds empty list when no docs present`() {
        val out = buildKycCertificates(
            aadhaarDocPath = null,
            panDocPath = null,
            certDocPaths = emptyList(),
            uploadedAt = now,
        )
        assertTrue(out.isEmpty())
    }

    @Test fun `aadhaar-only payload contains a single TYPE_AADHAAR entry`() {
        val out = buildKycCertificates(
            aadhaarDocPath = "uid/aadhaar-1.png",
            panDocPath = null,
            certDocPaths = emptyList(),
            uploadedAt = now,
        )
        assertEquals(1, out.size)
        assertEquals(EngineerCertificate.TYPE_AADHAAR, out[0].type)
        assertEquals("uid/aadhaar-1.png", out[0].path)
        assertEquals(now, out[0].uploadedAt)
    }

    @Test fun `pan-only payload contains a single TYPE_PAN entry`() {
        val out = buildKycCertificates(
            aadhaarDocPath = null,
            panDocPath = "uid/pan-1.png",
            certDocPaths = emptyList(),
            uploadedAt = now,
        )
        assertEquals(1, out.size)
        assertEquals(EngineerCertificate.TYPE_PAN, out[0].type)
        assertEquals("uid/pan-1.png", out[0].path)
    }

    @Test fun `cert paths expand into one TYPE_CERT entry per path`() {
        val out = buildKycCertificates(
            aadhaarDocPath = null,
            panDocPath = null,
            certDocPaths = listOf("uid/c-1.pdf", "uid/c-2.pdf", "uid/c-3.pdf"),
            uploadedAt = now,
        )
        assertEquals(3, out.size)
        assertTrue(out.all { it.type == EngineerCertificate.TYPE_CERT })
        assertEquals(listOf("uid/c-1.pdf", "uid/c-2.pdf", "uid/c-3.pdf"), out.map { it.path })
    }

    @Test fun `full payload preserves Aadhaar then PAN then certs order`() {
        // Order is load-bearing — Engineer.aadhaarDocPath / panDocPath use
        // lastOrNull, so this ordering also implicitly pins the "later entry
        // wins" semantics on re-submit.
        val out = buildKycCertificates(
            aadhaarDocPath = "uid/aadhaar.png",
            panDocPath = "uid/pan.png",
            certDocPaths = listOf("uid/c-1.pdf", "uid/c-2.pdf"),
            uploadedAt = now,
        )
        assertEquals(4, out.size)
        assertEquals(EngineerCertificate.TYPE_AADHAAR, out[0].type)
        assertEquals(EngineerCertificate.TYPE_PAN, out[1].type)
        assertEquals(EngineerCertificate.TYPE_CERT, out[2].type)
        assertEquals(EngineerCertificate.TYPE_CERT, out[3].type)
    }

    @Test fun `uploadedAt stamp is applied uniformly across every entry`() {
        val stamp = "2026-05-20T12:34:56.789Z"
        val out = buildKycCertificates(
            aadhaarDocPath = "uid/aadhaar.png",
            panDocPath = "uid/pan.png",
            certDocPaths = listOf("uid/c-1.pdf"),
            uploadedAt = stamp,
        )
        assertTrue(out.all { it.uploadedAt == stamp })
    }
}
