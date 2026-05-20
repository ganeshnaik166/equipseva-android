package com.equipseva.app.features.kyc

import com.equipseva.app.core.data.engineers.EngineerCertificate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class KycDocHelpersTest {

    @Test fun `docTypeLabel maps the three v1 doc types to friendly copy`() {
        assertEquals("Aadhaar", kycDocTypeLabel(EngineerCertificate.TYPE_AADHAAR))
        assertEquals("PAN", kycDocTypeLabel(EngineerCertificate.TYPE_PAN))
        assertEquals("certificate", kycDocTypeLabel(EngineerCertificate.TYPE_CERT))
    }

    @Test fun `docTypeLabel falls back to the raw key for unknown types`() {
        // Forwards-compat — a doc type added server-side still renders
        // (just with the storage key as its label) instead of throwing.
        assertEquals("trade_license", kycDocTypeLabel("trade_license"))
        assertEquals("selfie", kycDocTypeLabel(EngineerCertificate.TYPE_SELFIE))
    }

    @Test fun `timestampedName drops everything before the last slash`() {
        // SAF picker hands us URIs that may carry a path prefix; we only
        // want the trailing segment in the storage object key.
        val name = kycTimestampedName("content://com.android.providers.media/document/aadhaar.jpg")
        assertTrue("expected file segment at the end of $name", name.endsWith("-aadhaar.jpg"))
    }

    @Test fun `timestampedName replaces unsafe chars with underscore`() {
        // Supabase Storage rejects object keys with spaces / parentheses /
        // unicode. The sanitizer collapses anything outside [A-Za-z0-9._-]
        // to underscore.
        val name = kycTimestampedName("my doc (final).pdf")
        assertTrue("expected sanitized tail in $name", name.endsWith("-my_doc__final_.pdf"))
    }

    @Test fun `timestampedName preserves the dot, underscore, dash allow-list`() {
        val name = kycTimestampedName("a.b_c-d.png")
        assertTrue("expected exact tail in $name", name.endsWith("-a.b_c-d.png"))
    }

    @Test fun `timestampedName falls back to 'file' for a blank tail`() {
        val name = kycTimestampedName("path/to/")
        assertTrue("expected -file tail in $name", name.endsWith("-file"))
    }

    @Test fun `timestampedName starts with a numeric epoch prefix and a dash`() {
        val name = kycTimestampedName("doc.pdf")
        val parts = name.split("-", limit = 2)
        assertEquals(2, parts.size)
        // Epoch millis on this side of the year 2000 is at least 12 digits.
        assertTrue("expected numeric prefix in ${parts[0]}", parts[0].toLongOrNull() != null)
        assertTrue("expected positive epoch in ${parts[0]}", parts[0].toLong() > 0)
        assertEquals("doc.pdf", parts[1])
    }
}
