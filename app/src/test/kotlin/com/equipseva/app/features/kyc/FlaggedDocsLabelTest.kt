package com.equipseva.app.features.kyc

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins the comma-joined "flagged docs" label for the KYC re-upload
 * CTA. Critical regions:
 *
 *   * Each known doc-type key maps to the same UX strings the
 *     `docTypeLabel` helper uses (Aadhaar / PAN / certificate). Pin
 *     so the two helpers stay in sync — a rename would make the
 *     "Re-upload required: PAN" headline read differently from the
 *     "PAN uploaded" snackbar.
 *   * Returns null on empty list so the caller can pick the "all
 *     docs" copy variant (admin used a global rejection).
 *   * Unknown wire keys round-trip verbatim (forward-compat).
 */
class FlaggedDocsLabelTest {

    @Test fun `empty list returns null (admin used global rejection)`() {
        assertNull(flaggedDocsLabel(emptyList()))
    }

    @Test fun `single aadhaar key maps to Aadhaar`() {
        assertEquals("Aadhaar", flaggedDocsLabel(listOf("aadhaar")))
    }

    @Test fun `single pan key maps to PAN`() {
        assertEquals("PAN", flaggedDocsLabel(listOf("pan")))
    }

    @Test fun `single cert key maps to lowercase certificate (sentence-slot)`() {
        // Lowercase is intentional — the headline reads "Re-upload
        // required: certificate" / "Re-upload required: Aadhaar,
        // certificate" so the cert variant slots into a sentence
        // rather than reading as a title.
        assertEquals("certificate", flaggedDocsLabel(listOf("cert")))
    }

    @Test fun `multiple known keys are comma-joined in input order`() {
        assertEquals(
            "Aadhaar, PAN, certificate",
            flaggedDocsLabel(listOf("aadhaar", "pan", "cert")),
        )
    }

    @Test fun `unknown wire key passes through verbatim (forward-compat)`() {
        // A future doc type the client doesn't know yet — surfaces
        // the raw key so the admin's intent isn't lost.
        assertEquals("future_doc", flaggedDocsLabel(listOf("future_doc")))
    }

    @Test fun `mixed known plus unknown keys both surface`() {
        assertEquals(
            "Aadhaar, future_doc",
            flaggedDocsLabel(listOf("aadhaar", "future_doc")),
        )
    }

    @Test fun `case-sensitive matching - server emits lowercase`() {
        // "AADHAAR" / "Aadhaar" wire keys are not valid; the
        // mapping is case-sensitive so a typo surfaces.
        assertEquals("AADHAAR", flaggedDocsLabel(listOf("AADHAAR")))
        assertEquals("Aadhaar", flaggedDocsLabel(listOf("Aadhaar")))
    }
}
